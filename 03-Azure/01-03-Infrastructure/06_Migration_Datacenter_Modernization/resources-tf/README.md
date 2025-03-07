# Deploy the Landing Zone for the MicroHack

Use Azure Cloud Shell to deploy the MicroHack environment by following [Solution 1](../walkthrough/challenge-1/solution-tf.md).

## Quota Information if multiple Users Deploy to the same subscription

If you have multiple users deploying to the same subscription you need to make sure you have enough quota for the deployments. For a single user deployment, make sure to have the following quotas requested upfront:

| Quota name  | Required quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 30  |
| Standard DSv5 Family vCPUs  | 10  |
| Standard BS Family vCPUs  | 20  |
| Public IP Addresses - Standard | 10 |

That means for 5 Users that need to deploy individually to a Region you need to make sure you have the following quotas in place:

| Quota name  | Required quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 150  |
| Standard DSv5 Family vCPUs  | 50  |
| Standard BS Family vCPUs  | 100  |
| Public IP Addresses - Standard | 50 |

To request the quota please follow: https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal
