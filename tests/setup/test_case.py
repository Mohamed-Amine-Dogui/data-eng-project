from dataclasses import dataclass
from typing import Any, List


@dataclass
class TestCase:
    __test__ = False
    have: str
    want: Any


@dataclass
class TestTable:
    __test__ = False
    test_cases: List[TestCase]
