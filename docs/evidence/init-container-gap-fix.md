# Init Container Bypass -- Found and Fixed

## The gap
Initial Rego only evaluated `input.review.object.spec.containers`, meaning
an unsigned image placed in `initContainers` was never checked by Ratify
and passed admission cleanly.

## Proof of the gap (before fix)
kubectl apply -f policy/test-manifests/test-init-unsigned.yaml
> pod/test-init-unsigned created   (should have been blocked)

## The fix
Extended the Rego to concatenate containers, initContainers, and
ephemeralContainers before building the image list sent to Ratify.

## Proof of the fix (after)
kubectl apply -f policy/test-manifests/test-init-unsigned.yaml
> Error from server (Forbidden): admission webhook "validation.gatekeeper.sh"
> denied the request: [require-signed-images] image
> '5936/supply-chain-demo:unsigned-test' failed Cosign signature verification
