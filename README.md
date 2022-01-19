# Hello, World (Python/Flask)

This is a poc flask 
# Repository structure

The main files in this repository are:

* `Dockerfile` specifies how the application is built and packaged
* `service.yaml` contains values (typically configured by a developer) that will be instantiated into the Kubernetes manifest
* `app.py` is the actual Python/Flask application

# License

Licensed under Apache 2.0. Please see [LICENSE](LICENSE) for details.


 1873  curl -u admin:admin -X POST "http://localhost:9000/api/projects/create?project=test.project&name=shiny&branch=develop"
 1874  curl -u admin:admin -X POST "http://localhost:9000/api/user_tokens/generate?name=test_token"
 1875  curl -u admin:admin -X POST "http://localhost:9000/api/user_tokens/generate?name=test_token2"
 1876  sonar-scanner   -Dsonar.projectKey=test-project   -Dsonar.sources=.   -Dsonar.host.url=http://localhost:9000   -Dsonar.login=ea64baf53b160b2044efc1fa4341fa565ab7e262