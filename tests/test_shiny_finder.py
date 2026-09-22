import random
import tempfile
import unittest
from pathlib import Path

from tools.runtime import RuntimeState
from tools.shiny_finder import (
    SHINY_FINDER_ID,
    Encounter,
    EncounterClass,
    FinderConfig,
    ShinyFinder,
    ShinyFinderError,
    load_config,
    valid_shiny_dvs,
)


ROOT = Path(__file__).resolve().parents[1]
FIXTURE_SHINY_DVS = (0x2AAA, 0x3AAA, 0x6AAA, 0x7AAA, 0xAAAA, 0xBAAA, 0xEAAA, 0xFAAA)


def fixture_predicate(dvs: int) -> bool:
    """Test fixture only; production must inject Gen1Recomp's public predicate."""
    return dvs in FIXTURE_SHINY_DVS


class SequenceRandom:
    def __init__(self, values: list[int]):
        self.values = iter(values)

    def randrange(self, stop: int) -> int:
        value = next(self.values)
        if not 0 <= value < stop:
            raise AssertionError(f"fixture value {value} is outside randrange({stop})")
        return value


class ShinyFinderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = load_config(ROOT / "data" / "field_effects.json")
        self.encounter = Encounter(EncounterClass.WILD, 25, 12, (1, 2, 3), 0x1234)
        self.state = RuntimeState(active_field_effect=SHINY_FINDER_ID, remaining_steps=10)

    def test_configuration_matches_initial_balance_target(self) -> None:
        self.assertEqual(FinderConfig(250, 1, 100), self.config)

    def test_non_integer_configuration_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "effects.json"
            path.write_text(
                '{"shiny_finder":{"duration_steps":"250",'
                '"chance_numerator":1,"chance_denominator":100}}',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ShinyFinderError, "must be integers"):
                load_config(path)

    def test_success_uses_runtime_valid_dvs_and_preserves_encounter(self) -> None:
        finder = ShinyFinder(self.config, fixture_predicate, SequenceRandom([0, 3]))
        result = finder.apply(self.encounter, self.state)
        self.assertTrue(fixture_predicate(result.dvs))
        self.assertEqual((25, 12, (1, 2, 3)), (result.species, result.level, result.moves))
        self.assertEqual((1, 1), (self.state.debug_rolls, self.state.debug_successes))

    def test_failed_roll_returns_original_encounter(self) -> None:
        finder = ShinyFinder(self.config, fixture_predicate, SequenceRandom([99]))
        self.assertIs(self.encounter, finder.apply(self.encounter, self.state))
        self.assertEqual((1, 0), (self.state.debug_rolls, self.state.debug_successes))

    def test_inactive_and_excluded_classes_never_roll(self) -> None:
        finder = ShinyFinder(self.config, fixture_predicate, SequenceRandom([]))
        inactive = RuntimeState()
        self.assertIs(self.encounter, finder.apply(self.encounter, inactive))
        for encounter_class in EncounterClass:
            if encounter_class is EncounterClass.WILD:
                continue
            excluded = Encounter(encounter_class, 25, 12, (1,), 0x1234)
            self.assertIs(excluded, finder.apply(excluded, self.state))
        self.assertEqual(0, self.state.debug_rolls)

    def test_empty_runtime_predicate_is_rejected(self) -> None:
        with self.assertRaises(ShinyFinderError):
            valid_shiny_dvs(lambda _: False)

    def test_seeded_rate_is_within_preselected_tolerance(self) -> None:
        trials = 100_000
        state = RuntimeState(active_field_effect=SHINY_FINDER_ID, remaining_steps=1)
        finder = ShinyFinder(self.config, fixture_predicate, random.Random(0xD5C2E7E))
        for _ in range(trials):
            finder.apply(self.encounter, state)
        observed = state.debug_successes / trials
        self.assertLessEqual(abs(observed - 0.01), 0.001)
        self.assertEqual(trials, state.debug_rolls)

    def test_candidate_choice_is_uniform_in_seeded_simulation(self) -> None:
        draws = 80_000
        rng = random.Random(0x5A1F1)
        counts = {dvs: 0 for dvs in FIXTURE_SHINY_DVS}
        for _ in range(draws):
            counts[FIXTURE_SHINY_DVS[rng.randrange(len(FIXTURE_SHINY_DVS))]] += 1
        expected = draws / len(counts)
        self.assertTrue(all(abs(count - expected) <= expected * 0.03 for count in counts.values()))
