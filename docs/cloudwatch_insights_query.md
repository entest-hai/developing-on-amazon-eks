<!-- IMPORTANT: This document contains placeholder values that need to be replaced with actual values before use:
- YOUR_ACCOUNT_ID: Replace with your AWS account ID
- YOUR_CERTIFICATE_ID: Replace with your ACM certificate ID
- YOUR_OIDC_ID: Replace with your EKS OIDC provider ID
-->

# CloudWatch Logs Insights Queries for EKS Applications

This document provides detailed step-by-step instructions for querying logs for applications running on EKS using both CloudWatch Log Groups and CloudWatch Logs Insights.

## Querying Application Logs in CloudWatch Log Groups

### Step 1: Access CloudWatch Console
1. Open the AWS Management Console
2. Navigate to CloudWatch service
3. In the left navigation pane, select "Logs" > "Log groups"

### Step 2: Find the Application Log Group
1. Look for the log group named `/aws/containerinsights/eks-stack-eks-cluster/application`
2. Click on this log group to open it

### Step 3: Filter Logs for Specific Applications
1. In the search bar at the top of the log stream list, enter: `kubernetes.pod_name: app-name`
   - For go-bedrock-app: `kubernetes.pod_name: go-bedrock-app`
   - For go-book-app: `kubernetes.pod_name: go-book-app`
2. Press Enter or click the search icon
3. The results will show only log streams containing logs from the specified application pods

### Step 4: Refine Your Search
1. To filter for specific events, add more terms to your filter:
   - For errors: `kubernetes.pod_name: go-bedrock-app error`
   - For specific container: `kubernetes.pod_name: go-bedrock-app kubernetes.container_name: go-bedrock-app`
   - For specific namespace: `kubernetes.pod_name: go-bedrock-app kubernetes.namespace_name: default`

### Step 5: View Log Details
1. Click on any log stream in the filtered results
2. Browse through the log events
3. Click on any log event to expand and see the full details
4. Use the time controls at the top to adjust the time range if needed

## Querying Application Logs in CloudWatch Logs Insights

### Step 1: Access Logs Insights
1. In the CloudWatch console, select "Logs" > "Logs Insights" from the left navigation pane

### Step 2: Select the Application Log Group
1. In the dropdown menu at the top, select `/aws/containerinsights/eks-stack-eks-cluster/application`
2. Set the appropriate time range using the time selector in the upper right

### Step 3: Write a Basic Query for Applications

```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and log like /Latency/
| parse log "Latency: *ms" as latency
| sort @timestamp desc
| limit 100
```


1. In the query editor, replace any existing content with:
   ```
   fields @timestamp, @message
   | filter kubernetes.pod_name like /app-name/
   | sort @timestamp desc
   | limit 100
   ```
   - For go-bedrock-app:
     ```
     fields @timestamp, @message
     | filter kubernetes.pod_name like /go-bedrock-app/
     | sort @timestamp desc
     | limit 100
     ```
   - For go-book-app:
     ```
     fields @timestamp, @message
     | filter kubernetes.pod_name like /go-book-app/
     | sort @timestamp desc
     | limit 100
     ```
2. Click "Run query" to execute

### Step 4: Write Advanced Queries

#### Error Logs
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /error/i
| sort @timestamp desc
| limit 100
```

#### Pod Instance Statistics
```
fields @timestamp, @message, kubernetes.pod_name
| filter kubernetes.pod_name like /go-bedrock-app/
| stats count() by kubernetes.pod_name
```

#### Time-Specific Logs
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/
| filter @timestamp > parse_time('2025-05-18 00:00:00', 'yyyy-MM-dd HH:mm:ss')
| sort @timestamp desc
| limit 100
```

#### API Call Analysis
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /API request/
| parse @message "API request to * took * ms" as endpoint, duration
| stats avg(duration) as avg_duration, max(duration) as max_duration by endpoint
| sort avg_duration desc
```

#### Container Restart Analysis
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /Started container/
| stats count() as restart_count by kubernetes.pod_name
| sort restart_count desc
```

#### HTTP Status Code Analysis
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /HTTP/
| parse @message "HTTP * *" as status_code, endpoint
| stats count() by status_code, endpoint
| sort count() desc
```

### Step 5: Visualize Log Data
1. After running a statistical query, click on the "Visualization" tab
2. Select an appropriate visualization type (bar chart, line chart, etc.)
3. Adjust visualization settings as needed
4. To save the visualization to a dashboard, click "Add to dashboard"

### Step 6: Save and Share Queries
1. To save a useful query, click "Save" in the upper right
2. Give your query a name and description
3. To share results, click "Actions" > "Export results" and choose CSV or JSON format

### Step 7: Set Up Log Insights Alerts
1. Create a query that identifies conditions you want to be alerted on
2. Click "Actions" > "Create alarm"
3. Configure the alarm conditions, such as threshold and evaluation period
4. Set up notifications via SNS
5. Review and create the alarm

## Common Troubleshooting Queries

### Application Startup Issues
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /starting|initializing|bootstrap/i
| sort @timestamp asc
| limit 100
```

### Connection Issues
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /connection|timeout|refused|unreachable/i
| sort @timestamp desc
| limit 100
```

### Resource Issues
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /memory|cpu|resource|limit|quota/i
| sort @timestamp desc
| limit 100
```

### Authentication Issues
```
fields @timestamp, @message
| filter kubernetes.pod_name like /go-bedrock-app/ and @message like /auth|permission|denied|forbidden|unauthorized/i
| sort @timestamp desc
| limit 100
```

## Best Practices for Log Querying

1. **Use Time Windows Effectively**: Always narrow down your time range to the relevant period to improve query performance and focus on relevant logs.

2. **Leverage Pattern Matching**: Use the `like` operator with regular expressions for flexible pattern matching.

3. **Create Saved Queries**: Save frequently used queries to avoid rewriting them each time.

4. **Use Stats Commands**: Aggregate and analyze logs with `stats` commands to identify patterns and anomalies.

5. **Parse Structured Logs**: Use the `parse` command to extract structured data from log messages.

6. **Limit Results**: Always use `limit` to avoid overwhelming results, especially in high-volume environments.

7. **Create Dashboards**: Add important queries to CloudWatch dashboards for ongoing monitoring.

8. **Set Up Alerts**: Configure alarms for critical error patterns to get notified proactively.

## Conclusion

CloudWatch Logs Insights provides powerful querying capabilities for analyzing application logs in EKS. By using these queries and techniques, you can effectively troubleshoot issues, monitor application behavior, and gain insights into your containerized applications running on Amazon EKS.
