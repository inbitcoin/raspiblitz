## Proto build instructions

For every new lighter version the lighter RPC libs need to be compiled from
the matching protobuff files.
Do this on a raspberrypi with the exact same python version the scripts will
be are running on.
See https://lighter-doc.inbitcoin.it and
https://gitlab.com/inbitcoin/lighter/blob/develop/doc/client_libraries.md.

Make sure Virtual Environment is setup:
```
sudo apt-get -f -y install virtualenv
virtualenv lighter
source lighter/bin/activate
pip install grpcio grpcio-tools
```

Normally that is already done by build_sdcard.sh for user admin user. So just run:
```
source lighter/bin/activate
````

Now to generate the lighter RPC libs:
```
curl -o lighter.proto -s https://gitlab.com/inbitcoin/lighter/raw/develop/lighter/lighter.proto
python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. lighter.proto
````

*NOTE: If lighter master branch is already a version ahead use the
`lighter.proto` from the version tagged branch.*

Now copy the generated RPC libs per SCP over to your Laptop and add them to
the `/home/admin/config.scripts/lighterlibs`.
