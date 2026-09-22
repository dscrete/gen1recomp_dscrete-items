import unittest

from tools.runtime import ApplyResult, FieldEffects, RuntimeState, should_consume


class RuntimeTests(unittest.TestCase):
    def test_only_applied_transactions_consume(self) -> None:
        for result in ApplyResult:
            self.assertEqual(result is ApplyResult.APPLIED, should_consume(result))

    def test_activation_replacement_is_explicit(self) -> None:
        state = RuntimeState()
        effects = FieldEffects(state)
        self.assertEqual(ApplyResult.APPLIED, effects.activate("rare_lure", 10).result)
        self.assertEqual(ApplyResult.CANCELLED, effects.activate("shiny_finder", 20).result)
        replaced = effects.activate("shiny_finder", 20, replace=True)
        self.assertEqual(ApplyResult.APPLIED, replaced.result)
        self.assertEqual("rare_lure", replaced.replaced_effect)
        self.assertEqual(("shiny_finder", 20), (state.active_field_effect, state.remaining_steps))

    def test_only_eligible_steps_count_and_expiration_fires_once(self) -> None:
        state = RuntimeState()
        effects = FieldEffects(state)
        effects.activate("shiny_finder", 2)
        self.assertFalse(effects.on_step(eligible=False))
        self.assertEqual(2, state.remaining_steps)
        self.assertFalse(effects.on_step(eligible=True))
        self.assertTrue(effects.on_step(eligible=True))
        self.assertFalse(effects.on_step(eligible=True))

    def test_invalid_activation_does_not_change_state(self) -> None:
        state = RuntimeState()
        result = FieldEffects(state).activate("shiny_finder", 0)
        self.assertEqual(ApplyResult.INVALID_CONTEXT, result.result)
        self.assertIsNone(state.active_field_effect)
