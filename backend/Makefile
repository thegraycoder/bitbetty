deploy: package-api package-worker
	terraform apply

package-api:
	cd lambda/api && rm -rf .chalice/deployments && rm -rf deploy && chalice package deploy

package-worker:
	cd lambda/resolution-worker && rm -rf .chalice/deployments && rm -rf deploy && chalice package deploy