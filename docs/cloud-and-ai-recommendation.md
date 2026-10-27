# MyAaptha cloud and AI recommendation

Prepared: 6 September 2026. Recommendation, not a capacity guarantee or vendor quote.

## Readiness

The code and container preparation support proceeding to a controlled cloud staging deployment after real configuration is supplied. Public production remains gated on security/privacy acceptance, provider integrations, workload testing, and operational verification. See deployment-validation.md and MYAAPTHA-DEPLOYMENT-HANDOFF.md.

## Recommended cloud: AWS

For this application, start with ECS on Fargate for the Spring API, Next.js frontend and Python service; RDS PostgreSQL for data; private S3 for uploads; an application load balancer and CloudFront for delivery; Secrets Manager, CloudWatch and WAF for operations. This fits the application's existing PostgreSQL and S3 adapter and avoids operating Kubernetes initially.

Fargate runs containers without managing servers, and ECS supports service autoscaling. Sources: https://aws.amazon.com/fargate/ and https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html.

Use a single appropriate region initially, selected for your users and data requirements. For public production, plan multiple availability zones and database recovery. Increase service capacity based on measured concurrent requests, latency, database load, media traffic and AI usage.

Existing deployment templates are Kubernetes/Compose templates. ECS task definitions, networking and infrastructure provisioning must be implemented if this recommendation is selected; they were not silently deployed or substituted.

Google Cloud Run is a credible alternative for a small operations team and automatic container scaling. The current app needs a native GCS adapter or a suitable S3-compatible store, and its scheduled work must be reviewed for Cloud Run execution semantics. Source: https://docs.cloud.google.com/run/docs/about-instance-autoscaling.

## Growth from hundreds to millions

Start with a small measured deployment and a separate staging environment. Add worker queues for slow AI/uploads/notifications, database indexes and query tuning, connection-pool limits, pagination, caching and edge rate limits as measurements justify them. Test multi-replica scheduled jobs for duplicate execution before scaling. Validate media access and caching so private content cannot leak through the CDN.

A million registered users is not a million concurrent users. For illustration, one million accounts with 10% daily active users and 30 API requests per active user produce three million requests/day, about 35 requests/second on average. Bursts, polling/chat, uploads and AI calls can change that substantially. This arithmetic is not a sizing result for MyAaptha.

Do not claim million-user capacity from local unit tests or from the cloud provider's ability to scale. Re-run representative staging load tests and define latency/error budgets before each expansion.

## Recommended initial AI provider: OpenAI API

Use OpenAI as the first integration because MyAaptha already has an OpenAI health-report adapter and it supports structured responses and tool-based workflows. This is a practical starting choice, not proof it is universally better than other providers.

Evaluate GPT-5.6 Luna for low-cost, high-volume extraction/classification, GPT-5.6 Terra for more involved assistant tasks, and a stronger model only where measured accuracy justifies the cost. Current OpenAI model guidance describes those roles: https://developers.openai.com/api/docs/models. No existing application model was changed solely because of this recommendation; model/API changes require evaluation.

Use task-specific application APIs for actions such as categorizing a transaction, drafting a reminder or suggesting relationship labels. The server checks identity, permissions, arguments and user approval before execution, and records an audit event. Do not let the model write arbitrary database queries or execute unrestricted administrative tools. OpenAI tool guidance: https://developers.openai.com/api/docs/guides/tools.

Start automation with contact organization, document field extraction, expense categorization, reminder drafts and support answers grounded in product documentation. Require confirmation for messages, deletion, payments, access grants, emergency actions and consequential health decisions. Existing approval controls are a foundation, not proof every workflow is integrated end to end.

Compare OpenAI with Claude and Gemini on a small representative evaluation set (including required Indian languages), measuring task success, errors, latency and cost per completed task. Claude tool use: https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works. Gemini function calling: https://ai.google.dev/gemini-api/docs/function-calling.

If AWS-native identity, private connectivity and governance outweigh direct-provider convenience, evaluate Amazon Bedrock with an available model in your chosen region. Bedrock is a model hosting platform, not a single model. Source: https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html.

Hosting on AWS does not require using AWS as the AI provider. For health/finance/contact data, minimize what is sent, obtain the required consent and validate model/region/retention terms. OpenAI API data is not used for training by default, but retention depends on the endpoint and approved controls; do not assume zero retention. Source: https://developers.openai.com/api/docs/guides/your-data.

## Cost control

Choose the smallest model that passes your evaluation; use deterministic code for simple rules, short outputs, per-user quotas, retry/time limits, queueing and spending alerts. Measure cost per successful task, including retries and tool fees. Cloud, AI, SMS, storage and media egress need separate budget lines. A defensible estimate needs your peak concurrency, daily active users, uploads and AI tasks per user.
