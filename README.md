## Synopsis

Fullstack demo application based on RoR & React / Semantic-UI.

## Deployment instructions

```
% sudo docker build --tag fullstack-ror-api-demo .
% sudo docker run -it --privileged --rm \
	-e AMAZON_ACCESS_KEY_ID=... \
	-e AMAZON_ASSOCIATE_TAG_ID=... \
	-e AMAZON_SECRET_KEY=... \
	-p 3000:3000 \
	fullstack-ror-api-demo
```

## Requirements

 * system capable to run RoR
 * Amazon Affliate account

## Limitations

 * Currently limited to Amazon Canada

