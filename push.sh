set -eux
docker image build . -t johngarbutt/io500
docker run --rm johngarbutt/io500
docker image push johngarbutt/io500
