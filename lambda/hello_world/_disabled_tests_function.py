import function


def test_function_can_access_boto3():
    assert function.handler(None, None)
