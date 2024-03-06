"""
Define pytest cli additional arguments. E.g:
Getting the model service endpoint via the option: pytest ... --model-endpoint http://model-service:80
"""

import pytest
from _pytest.config.argparsing import Parser


def pytest_addoption(parser: Parser):
    """
    Add parameters that pytest will listen too when called.
    """
    parser.addoption("--model-endpoint")
    parser.addoption("--salutation")


@pytest.fixture()
def model_endpoint(request):
    """
    What value from cli option --model-endpoint (model_endpoint) is made available in the test
    when option is used.
    The lib replaces "-" by "_" (as declared in pytest_addoption): model-endpoint becomes
    model_endpoint.
    """
    return request.config.option.model_endpoint


@pytest.fixture()
def salutation(request):
    return request.config.option.salutation
