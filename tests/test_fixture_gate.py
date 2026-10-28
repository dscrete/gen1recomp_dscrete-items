import unittest

from tools.fixture_gate import accepted_output, EXPECTED_MISSING_COUNT


def missing(index):
    # The fixture is intentionally missing regular vanilla Rocket party data.
    species = ["RATTATA", "ZUBAT", "RATICATE", "GOLBAT", "DROWZEE"]
    name = ["RONNIE", "MILO", "CASS"][index % 3]
    return (
        f'MK102 ERROR gen1recomp_dscrete_items: '
        f'trainers.OPP_DS_{name}.parties[1][{index+1}].species: '
        f'unresolved reference to pokemon "{species[index % len(species)]}"'
    )


def fixture_output(lines):
    return "\n".join(lines + ["FAIL gen1recomp_dscrete_items invalid"])


class FixtureGateTests(unittest.TestCase):
    def test_clean_success_is_accepted(self):
        self.assertTrue(accepted_output(0, "PASS gen1recomp_dscrete_items")[0])

    def test_known_missing_trainer_fixture_records_are_accepted(self):
        output = fixture_output([missing(i) for i in range(EXPECTED_MISSING_COUNT)])
        ok, _ = accepted_output(2, output)
        self.assertTrue(ok)
        self.assertTrue(accepted_output(1, output)[0],
                        "modkit currently exits 1 for validation findings")

    def test_unrelated_missing_item_is_fatal(self):
        lines = [missing(i) for i in range(EXPECTED_MISSING_COUNT)]
        lines[0] = (
            'MK102 ERROR gen1recomp_dscrete_items: items.DS_THING: '
            'unresolved reference to pokemon "TYPO"'
        )
        self.assertFalse(accepted_output(2, fixture_output(lines))[0])

    def test_new_engine_error_is_fatal(self):
        lines = [missing(i) for i in range(EXPECTED_MISSING_COUNT)]
        lines.append("MK999 ERROR gen1recomp_dscrete_items: new schema error")
        self.assertFalse(accepted_output(2, fixture_output(lines))[0])

    def test_missing_expected_references_do_not_silently_pass(self):
        self.assertFalse(accepted_output(2, fixture_output([missing(0)]))[0])

    def test_crash_does_not_silently_pass(self):
        lines = [missing(i) for i in range(EXPECTED_MISSING_COUNT)]
        lines.append("Traceback (most recent call last)")
        self.assertFalse(accepted_output(2, fixture_output(lines))[0])

    def test_unknown_status_or_incomplete_validation_is_fatal(self):
        self.assertFalse(accepted_output(1, "connection error")[0])
        self.assertFalse(accepted_output(2, "\n".join([missing(i) for i in range(33)]))[0])


if __name__ == "__main__":
    unittest.main()
