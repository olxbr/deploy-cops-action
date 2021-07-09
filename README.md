# deploy-cops-action

Action to deploy application on COPS.

## Usage

```yaml
# .github/workflows/my-workflow.yml
jobs:
    my_job:
        ...
        runs-on: [self-hosted, ...]
        steps:
            - id: deploy-cops
              uses: olxbr/deploy-cops-action@v2
              with:
                # We suggest adding COPS url as repository secret
                url: ${{ secrets.COPS_URL }}
                # You can use the image from some other action output or something else
                image: ${{ needs.build-n-push-docker-img.outputs.image }}
                # Tolerance in seconds to wait the deploy to be successfull
                timeout_in_seconds: 600

            - ... other steps
```

## Prerequisites

### Runner Self-Hosted
You have to use the **self-hosted runner** to deploy your app in the specific environment.

### COPS URL
We suggest adding COPS url as repository secret.

### Image URL
You can use the image from some other action output or something else. The image can be from different sources as long as COPS is able to use it.
