run: build
	docker run \
	  --name vm \
	  --hostname vm \
	  --rm \
	  -itd \
	  --privileged \
	  -p 13307:22 \
	  -p 13306:5900 \
	  -v /dev/kvm:/dev/kvm \
	  -v $$PWD:/work \
	  -w /work \
	  yaamai/alpine-qemu:latest \
	    images/arch-openstack-2019-09-05-06-25-image-bootstrap-0.9.2.1-81-gcbb5fd6.qcow2
attach:
	docker attach vm --detach-keys=ctrl-t
stop:
	docker stop vm
build: Dockerfile entrypoint.sh
	docker build . -t yaamai/alpine-qemu:latest
