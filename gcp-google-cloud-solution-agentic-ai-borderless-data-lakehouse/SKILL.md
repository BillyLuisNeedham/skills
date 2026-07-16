---
name: google-cloud-solution-agentic-ai-borderless-data-lakehouse
description: >-
  Guides agents to discover requirements and design a governed,
  secure borderless open data lakehouse with agentic AI integration. Use when
  designing a multi-product architecture that connects data silos to AI agents,
  joining data across clouds, or running federated queries across Google Cloud
  and external data sources, including on-premises or other cloud providers.
  Don't use for simple single-cloud data warehouses or non-AI workloads.
---

# Borderless open data lakehouse agentic AI system

Follow this workflow to help users design and implement a custom multi-product
solution in the cloud for a given workload, use case, or requirement.

## Product Renaming & Terminology

When generating solution designs, architecture diagrams, and documentation, use
the updated Google Cloud product names. Note that underlying APIs, Terraform
resources, and IAM roles often retain their legacy identifiers.

<table>
  <thead>
    <tr>
      <th>Legacy Name</th>
      <th>Updated Name</th>
      <th>Notes / API Identifiers</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Vertex AI</td>
      <td>Gemini Enterprise Agent Platform</td>
      <td>Used for AI serving and agentic workflows.</td>
    </tr>
    <tr>
      <td>BigLake</td>
      <td>Lakehouse for Apache Iceberg</td>
      <td>
        Used for central metadata and governance. Terraform resources (e.g.,
        <code>google_biglake_table</code>,
        <code>google_biglake_repository</code>) and APIs still use
        <code>biglake</code>.
      </td>
    </tr>
    <tr>
      <td>Dataproc Serverless</td>
      <td>Managed Service for Apache Spark</td>
      <td>
        Used for distributed processing. APIs and IAM roles still use
        <code>dataproc</code>.
      </td>
    </tr>
    <tr>
      <td>Dataplex</td>
      <td>Knowledge Catalog</td>
      <td>Used for active context and governance.</td>
    </tr>
    <tr>
      <td>cross-cloud, multicloud, multi-cloud</td>
      <td>borderless</td>
      <td>
        Rephrase all occurrences to <code>borderless</code>, with the exception
        of the product <code>Cross-Cloud Interconnect</code>.
      </td>
    </tr>
  </tbody>
</table>

## Workflow

The solution design and implementation workflow consists of the following
phases:

- **Phase 1: Requirements discovery and analysis**: Analyze the workload's
  requirements, constraints, dependencies, and current state.
- **Phase 2: Solution design**: Build a technology stack, architecture, and
  deployment configuration for the workload based on Google Cloud design best
  practices and recommendations.
- **Phase 3: Implementation plan**: Generate automation
  and instructions to deploy the solution.
- **Phase 4: Solution validation**: Validate that the deployment meets the
  requirements of the workload.

### Phase 1: Requirements discovery and analysis

1. **Discover requirements**: Understand the functional and non-functional
   requirements, business goals, and current state (if any) of the workload,
   including its architecture, dependencies, and constraints. Use the
   following questions to guide the requirements discovery process:
   - What are your primary data sources?
   - How do you manage and federate metadata across your data sources?
   - What are your security and credential management requirements?
   - What are the analytical and computational requirements to join and
     transform this borderless data?
   - What types of natural language prompts or user queries do you expect AI
     agents or end-users to execute against this data?

2. **Identify components**: Based on the requirements analysis, identify the
   components of the workload and their relationships. Also identify any
   borderless components, hybrid components, or on-prem components that the
   solution needs to integrate with.

3. **Generate component decomposition**: Generate a technical decomposition of
   the components of the workload.

4. **Ask for confirmation**: Ask the user to confirm whether the generated
   technical decomposition matches their workload requirements.

5. **Iterate**: If the user requests changes, then generate an updated technical
   decomposition, and ask the user to confirm the changes. Continue iterating
   until the user confirms the technical decomposition.

### Phase 2: Solution design

1.  **Retrieve relevant Google Cloud documentation**:

   - [Build hybrid and borderless architectures using Google Cloud](https://docs.cloud.google.com/architecture/hybrid-multicloud-patterns/one-page-view.md.txt)
   - [Build a borderless open data lakehouse](https://docs.cloud.google.com/architecture/agentic-ai-build-multicloud-open-data-lakehouse.md.txt)
   - [Implement agentic analytics workflows for distributed data](https://docs.cloud.google.com/architecture/agentic-ai-cross-cloud-analytics.md.txt)
   - [Analytics Hybrid and Multicloud Pattern](https://docs.cloud.google.com/architecture/hybrid-multicloud-patterns-and-practices/analytics-hybrid-multicloud-pattern.md.txt)
   - [Google Cloud multi-regional deployment archetype](https://docs.cloud.google.com/architecture/deployment-archetypes/multiregional.md.txt)
   - [Network segmentation and connectivity for distributed applications in Cross-Cloud Network](https://docs.cloud.google.com/architecture/ccn-distributed-apps-design/connectivity.md.txt)
   - [Patterns for Connecting Other Cloud Service Providers with Google Cloud](https://docs.cloud.google.com/architecture/patterns-for-connecting-other-csps-with-gcp.md.txt)

   *Important*: Use the content that you retrieve from Google Cloud
   documentation to ground the guidance that you generate in the remaining
   steps of this phase.

2. **Map components to Google Cloud products**: Explain to the user that the
   solution consists of two subsystems:
   - The **data ingestion subsystem** ingests data from external sources and
     uses a central lakehouse to unify and process fragmented databases into a
     unified data profile in Google Cloud.
   - The **serving subsystem** lets users query an AI assistant and a data
     analysis agent to analyze the consolidated data.

   For each component in the
   confirmed technical decomposition, identify the appropriate Google Cloud
   products and features, based on the following guidance:

    - **Data ingestion subsystem components**:
       - **Central metadata and governance**
          - **Recommended primary product**: Lakehouse for Apache Iceberg
          - **Alternative product1**: Dataproc Metastore
              - **Pros**: Better for legacy open-source heavy pipelines.
              - **Cons**: Can have lower performance for borderless federation
                and Apache Iceberg.
       - **Processing engine**
          - **Recommended primary product**: Managed Service for Apache Spark
            with Lightning Engine
          - **Alternative product1**: BigQuery
              - **Pros**: Allows querying data in place on external clouds using
                standard SQL, reducing data movement.
              - **Cons**: Less flexible than Spark for highly complex,
                programmatic transformations or custom code.
          - **Alternative product2**: Dataflow
              - **Pros**: Powerful for complex, unified batch or stream ETL.
              - **Cons**: Requires learning the Apache Beam programming model
                and managing a Cloud Storage bucket for job error logs.
       - **Internal data storage**
          - **Recommended primary product**: Cloud Storage using Apache Iceberg
            format or Apache Parquet format.
          - **Alternative product1**: BigQuery storage
              - **Pros**: Provides high performance for native BigQuery queries.
              - **Cons**: Less portable for other open-source processing engines
                compared to open formats on Cloud Storage.
          - **Alternative product1**: Cloud Storage
              - **Pros**: Eliminates borderless egress fees and latency if you
                choose to consolidate your workload to a single cloud.
       - **Security**
          - **Recommended primary product**: Use Secret Manager to securely
            hold authentication credentials for federated REST catalogs. Manage
            direct storage object access using BigQuery Cloud Resource
            connections and runtime credential vending.
          - **Alternative product1**: Cloud Key Management Service (KMS)
              - **Pros**: Provides hardware-backed key management for
                encryption.
              - **Cons**: Not designed to store plain-text secrets like API
                tokens.
       - **Borderless networking**
          - **Recommended primary product**: Cross-Cloud Interconnect
          - **Alternative product1**: Cloud VPN (HA VPN)
              - **Pros**: Offers lower costs during low-traffic periods.
              - **Cons**: Can have higher latency and lower bandwidth compared
                to dedicated Cross-Cloud Interconnect.
    - **Serving subsystem components**:
       - **AI serving and agentic workflows**:
          - **Recommended primary product**: BigQuery data agent with
          Antigravity CLI
          - **Alternative product1**: Gemini Enterprise Agent Platform
              - **Pros**: Provides built-in orchestration, native enterprise
                grounding, and managed chat UIs.
              - **Cons**: Offers less granular control over the prompt
                loop, and can be more expensive than a lightweight MCP server.
          - **Alternative product2**: Google Cloud Data Agent Kit
              - **Pros**: Optimized for data practitioners, data engineers, and
                data scientists to manage the data lifecycle and perform
                interactive analysis directly within their IDE.
              - **Cons**: Designed for developer-centric workflows rather than
                serving production end-to-end business applications.

3. **Create architecture diagram**: Create an architecture diagram that shows
   the components, their relationships, and data/control flows.
   - The diagram must be in the Mermaid format:
     https://github.com/mermaid-js/mermaid.
   - The diagram must use component labels and groupings consistent with the
     official Google Cloud architecture icons.
   - The diagram must show a clear distinction between the products in the
     data ingestion subsystem and the serving subsystem.
   - The diagram must show Managed Service for Apache Spark as a shared
     component, bridging the data ingestion and serving subsystems.

4. **Generate design recommendations**: Generate design guidance based on the
   following Google Cloud best practices and recommendations:
    - **Security, privacy, and compliance**:
      - To create and manage permissions for Google Cloud resources, use
        Google's Identity and Access Management (IAM) service.
      - To securely access raw data in Cloud Storage, use BigQuery Cloud
        resource connections.
      - To securely manage borderless external catalog authentication, use the
        security standard of the source platform to choose between Lakehouse
        Iceberg REST catalog federation with Secret Manager and OIDC token
        federation.
      - To delegate storage access and apply fine-grained IAM policies at the
        table level for tables stored in Cloud Storage, enable credential
        vending for your Lakehouse for Apache Iceberg runtime catalog.
      - To enforce the principle of least privilege, manage access through
        system-managed identities.
      - Use Cloud NAT and Cloud Router to enable resources in private subnets to
        securely access external cloud sources without exposure to the public
        internet.
      - Use Sensitive Data Protection to discover, classify, and de-identify
        sensitive data in prompts, responses, and data lake files using masking
        or encryption.
      - For more information about security, privacy, and compliance in Google
        Cloud, see
https://cloud.google.com/architecture/framework/perspectives/ai-ml/security.md.txt
    - **Reliability**:
      - To ensure reliable performance and minimize data transfer costs over
        borderless networks, use Cross-Cloud Interconnect to establish a
        private connection between Google Cloud and other cloud providers,
        avoiding the unpredictable latency of the public internet.
      - Configure Dedicated or Partner Interconnect with redundant connections
        in different edge availability domains and locations.
      - Use Cloud DNS routing policies to route traffic to regional load
        balancers, enabling automatic failover to alternative regions during
        outages.
      - For more information about reliability in Google Cloud, see
https://cloud.google.com/architecture/framework/perspectives/ai-ml/reliability.md.txt
    - **Operational excellence**:
      - Place external connections and routing in a dedicated transit VPC to
        serve as a shared, modular connectivity service for other VPCs and
        simplify network administration.
      - Use Terraform as the Infrastructure as Code (IaC) tool to define and
        automate the provisioning of heterogeneous resources, ensuring
        consistency across environments.
      - Configure bidirectional DNS forwarding between Cloud DNS and external
        DNS servers to enable seamless name resolution across hybrid
        environments.
      - For more information about operational excellence in Google Cloud, see
https://cloud.google.com/architecture/framework/perspectives/ai-ml/operational-excellence.md.txt
    - **Cost optimization**:
      - To save costs and overhead associated with building and maintaining CDC
        pipelines, use BigQuery federated queries to AlloyDB to query your data
        directly.
      - In cases where latency is not critical, use the Standard Network Service
        Tier for outbound internet traffic to reduce network egress costs.
      - For more information about cost optimization in Google Cloud, see
https://cloud.google.com/architecture/framework/perspectives/ai-ml/cost-optimization.md.txt
    - **Performance efficiency**:
      - To mitigate AI model hallucinations, ground your model on the unified
        data profile to enforce business definitions and statistical validation.
      - To perform exact-match filters to operational databases, use BigQuery
        federated queries.
      - To offload memory-heavy and complex data manipulation, such as
        vectorized borderless joins, use Managed Service for Apache Spark with
        Lightning Engine.
      - Use Cross-Cloud Interconnect to establish high-bandwidth, low-latency
        private connections to other CSPs to maximize throughput for distributed
        applications.
      - Configure redundant intra-regional network connections in an
        active/active design using Equal Cost Multi-Path (ECMP) routing to
        aggregate bandwidth.
      - Select Google Cloud regions that are geographically close to the
        external CSP's regions to minimize latency and improve data transfer
        performance.
      - For more information about performance efficiency in Google Cloud, see
https://cloud.google.com/architecture/framework/perspectives/ai-ml/performance-efficiency.md.txt
    - **Sustainability**:
      - To maximize compute efficiency and reduce energy consumption, use
        Managed Service for Apache Spark with Lightning Engine to handle massive
        joins and complex windowing.
      - Use BigQuery Omni to query data in place on AWS or Azure (Amazon S3 or
        Azure Blob Storage) to avoid resource-intensive borderless data
        replication.
      - For more information about sustainability considerations, see the
https://docs.cloud.google.com/architecture/framework/sustainability/printable.md.txt.

5. **Draft solution architecture**: Compile the requirements, technical
   decomposition, product mapping, architecture diagram, and design
   recommendations into a single Markdown file named
   `solution-architecture-guide.md`, based on the template in
   `assets/output-template.md`.

6. **Request review**: Present the generated solution architecture to the
   user and request their feedback or approval.

7. **Iterate**: If the user requests changes, generate an updated solution
   architecture and repeat steps 2-6 until the user approves the solution
   architecture.

### Phase 3: Implementation plan

1.  **Retrieve relevant implementation resources**:

    - [Build a Multicloud Open Data Lakehouse with Agentic AI](https://codelabs.developers.google.com/next26/multicloud-lakehouse)
    - [Terraform Registry documentation for biglake_iceberg_catalog](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/biglake_iceberg_catalog)
    - [Create an Apache Iceberg table with metadata in Lakehouse runtime catalog](https://docs.cloud.google.com/managed-spark/docs/guides/spark-workloads-with-bigquery-metastore.md.txt)
    - [Accelerate Spark batch workloads and sessions with Lightning Engine](https://docs.cloud.google.com/managed-spark/docs/guides/lightning-engine-serverless.md.txt)
    - [Create data agents](https://docs.cloud.google.com/bigquery/docs/create-data-agents.md.txt)

    *Important*: Use these resources as the technical foundation for the IaC and
    deployment instructions you generate in the remaining steps of this phase.

2. **Identify deployment prerequisites**: Document prerequisites for the
   deployment, including the following:
   - Projects and billing associations
   - Required Google Cloud APIs
   - Required IAM permissions
   - Any other prerequisites

3. **Generate Infrastructure as Code (IaC)**: Generate code (e.g., Terraform)
   and deployment scripts to automate the provisioning of the proposed
   Google Cloud resources.

4. **Write deployment instructions**: Draft sequential, step-by-step deployment
   instructions to execute the IaC and initialize the workload components.

5. **Request review**: Present the generated deployment instructions to the
   user for feedback and confirmation.

6. **Iterate**: If the user requests changes, generate an updated implementation
   plan and repeat steps 2-5 until the user approves the implementation plan.

### Phase 4: Solution validation

1.  **Retrieve relevant verification resources**:

    - [Build a Multicloud Open Data Lakehouse with Agentic AI](https://codelabs.developers.google.com/next26/multicloud-lakehouse)
    - [Create and run Connectivity Tests](https://docs.cloud.google.com/network-intelligence-center/docs/connectivity-tests/how-to/running-connectivity-tests.md.txt)
    - [Create an Apache Iceberg table with metadata in Lakehouse runtime catalog](https://docs.cloud.google.com/managed-spark/docs/guides/spark-workloads-with-bigquery-metastore.md.txt)
    - [Accelerate Spark batch workloads and sessions with Lightning Engine](https://docs.cloud.google.com/managed-spark/docs/guides/lightning-engine-serverless.md.txt)

    *Important*: Use these resources and their verification patterns as the
    starting point for the validation checks and verification scripts you
    generate in the remaining steps of this phase.

2.  **Define validation checks**: Outline validation steps to verify that the
    deployed infrastructure meets the workload's requirements:

    -   **Deployment dry-run**: Commands like `terraform plan` to preview
        changes.
    -   **Connectivity and routing**: Verification of network paths, load
        balancer routing, and service endpoints.
    -   **Security policies**: Verification of restricted access, firewall
        rules, and IAM enforcement.

3.  **Generate verification scripts**: Draft lightweight scripts or command-line
    instructions (e.g. using `curl` or `gcloud`) that the user can run to
    perform these validation checks.

4.  **Compile validation report**: Document the validation steps, verification
    scripts, and expected outcomes in single Markdown file.

5.  **Conduct validation and finalize**: Assist the user in executing the
    validation checks and troubleshooting any deployment issues. After the
    solution is validated successfully, request final approval from the user.

6.  **Iterate**: If the user requests changes, then generate an updated
    validation plan and repeat steps 2-5 until the user approves the validation
    plan.

## Supporting Links

- [Build hybrid and multicloud architectures using Google Cloud](https://docs.cloud.google.com/architecture/hybrid-multicloud-patterns/one-page-view.md.txt)
- [Build a borderless open data lakehouse](https://docs.cloud.google.com/architecture/agentic-ai-build-multicloud-open-data-lakehouse.md.txt)
- [Implement agentic analytics workflows for distributed data](https://docs.cloud.google.com/architecture/agentic-ai-cross-cloud-analytics.md.txt)
- [Analytics Hybrid and Multicloud Pattern](https://docs.cloud.google.com/architecture/hybrid-multicloud-patterns-and-practices/analytics-hybrid-multicloud-pattern.md.txt)
- [Google Cloud multi-regional deployment archetype](https://docs.cloud.google.com/architecture/deployment-archetypes/multiregional.md.txt)
- [Network segmentation and connectivity for distributed applications in Cross-Cloud Network](https://docs.cloud.google.com/architecture/ccn-distributed-apps-design/connectivity.md.txt)
- [Patterns for Connecting Other Cloud Service Providers with Google Cloud](https://docs.cloud.google.com/architecture/patterns-for-connecting-other-csps-with-gcp.md.txt)
