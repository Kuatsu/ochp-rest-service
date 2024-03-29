# ochp-rest-service

This is a wrapper REST server around the OCHP 1.4 SOAP protocol, completely built in Ruby. Currently, it only supports the static `GetChargePointList` and the live `GetStatus` methods as well as several methods from the OCHPdirect protocol.

The REST server completely parses the SOAP response from OCHP into JSON and responds with that. An OpenAPI 3.0 / Swagger documentation is available in the `openapi.yml` file within this repository.

It was built to be used as a microservice for another backend, like Node.js, to talk to. Existing JavaScript SOAP client solutions often don't cover more complex scenarios and don't manage nested WSDL files, like OCHP's, well. Therefore, using this wrapper around the existing protocol, your backend can easily parse the provided JSON and continue working with that.

Please note that this wrapper does not provide any security or caching features whatsoever: It immediately passes any request to the SOAP protocol without any further checks. Those should therefore be implemented in the parent service and under no circumstances should this REST service be exposed to the outside.

## Usage

Either run through the provided Dockerfile (making sure to pass in the needed environment variables from `.env.example` to Docker) or run manually:

1. Run `bundle install` to install the needed gems.
2. Then, either copy `.env.example` to an `.env` file and fill the needed values, or set those environment variables directly within your system / CI pipeline.
3. Lastly, simply run `ruby src/main.rb` to start the Sinatra / Puma server.

## Building & pushing images to GitHub

To build a new version of the Docker image, make sure to log into the GitHub container registry first as per [the documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry), then run this command from the root directory of this repo:

`docker buildx build --push --platform linux/x86_64,linux/arm64 -t ghcr.io/kuatsu/ochp-rest-service:[version] -t ghcr.io/kuatsu/ochp-rest-service:latest --no-cache --pull .`

Make sure to replace `[version]` with a new version identifier. The version identifier should consist of the current OCHP version used (e.g. 1.4), followed by a hyphen and the newest build number, e.g.: `1.4-6`.

The image will be pushed automatically to the container registry.
