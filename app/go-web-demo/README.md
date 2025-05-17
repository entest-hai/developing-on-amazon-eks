---
title: a simple web app using golang
description: a very simple web app in golang
author: haimtran
date: 01/04/2024
---

## Introduction

Use golang to build a very simple webapp

- serve a static book page
- query postgresql and return a list book
- userdata to deploy on EC2
- dockerize to deploy somewhere else

[Github](https://github.com/cdk-entest/go-web-demo)

## Setup PostgreSQL

Install psql client

```bash
sudo dnf install postgresql15.x86_64 postgresql15-server
```

Connect to the PostgreSQL instance

```bash
psql -h $HOST -p 5432 -U postgresql -d demo
```

List database

```sql
\l
```

Use database

```sql
\c demo;
```

List table

```sql
\dt
```

Create a table

```sql
CREATE TABLE IF NOT EXISTS book (
  id serial PRIMARY KEY,
  author TEXT,
  title TEXT,
  amazon TEXT,
  image TEXT
);
```

Insert to a table

```sql
INSERT INTO book (author, title, amazon, image)
values ('Hai Tran', 'Deep Learning', '', 'golang-idiomatic.jpg') RETURNING id;
```

Delete a record

```sql
DELETE FROM book where id=1;
```

## Go Application

- Static book page
- PostgreSQL page

project structure

```go
|--static
   |book-template.html
|--index.html
|--main.go
|--simple.go
```

This is webserver

<details>
<summary>main.go</summary>

```go
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"text/template"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime/types"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/schema"
)

// aws rds
// const HOST = "database-1.c9y4mg20eppz.ap-southeast-1.rds.amazonaws.com"
// const USER = "postgresql"
// const PASS = "Admin2024"
// const DBNAME = "demo"

// local db
const HOST = "localhost"
const USER = "postgres"
const DBNAME = "dvdrental"
const PASS = "Mike@865525"

type Book struct {
	ID          uint
	Title       string
	Author      string
	Amazon      string
	Image       string
	Description string
}

func main() {

	// db init
	dns := fmt.Sprintf("host=%v port=%v user=%v password=%v dbname=%v", HOST, "5432", USER, PASS, DBNAME)
	db, _ := gorm.Open(postgres.Open(dns), &gorm.Config{
		NamingStrategy: schema.NamingStrategy{
			NoLowerCase:   false,
			SingularTable: true,
		},
	})

	mux := http.NewServeMux()

	// home page
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/bedrock.html")
	})

	// book page
	mux.HandleFunc("/book", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/book.html")
	})

	mux.HandleFunc("/postgresql", func(w http.ResponseWriter, r *http.Request) {

		// query a list of book []Book
		books := getBooks(db)

		// load template
		tmpl, error := template.ParseFiles("./static/book-template.html")

		if error != nil {
			fmt.Println(error)
		}

		// pass data to template and write to writer
		tmpl.Execute(w, books)
	})

	// upload page
	mux.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			http.ServeFile(w, r, "./static/upload.html")
		case "POST":
			uploadFile(w, r, db)
		}
	})

	// bedrock page
	mux.HandleFunc("/bedrock-stream", bedrock)

	// create web server
	server := &http.Server{
		Addr:           ":3000",
		Handler:        mux,
		ReadTimeout:    30 * time.Second,
		WriteTimeout:   30 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	// static files
	mux.Handle("/demo/", http.StripPrefix("/demo/", http.FileServer(http.Dir("./static"))))

	// enable logging
	log.Fatal(server.ListenAndServe())

}

func getBooks(db *gorm.DB) []Book {
	var books []Book

	db.Limit(10).Find(&books)

	for _, book := range books {
		fmt.Println(book.Title)
	}

	return books
}

func uploadFile(w http.ResponseWriter, r *http.Request, db *gorm.DB) {

	// maximum upload file of 10 MB files
	r.ParseMultipartForm(10 << 20)

	// Get handler for filename, size and heanders
	file, handler, error := r.FormFile("myFile")
	if error != nil {
		fmt.Println("Error")
		fmt.Println(error)
		return
	}

	defer file.Close()
	fmt.Printf("upload file %v\n", handler.Filename)
	fmt.Printf("file size %v\n", handler.Size)
	fmt.Printf("MIME header %v\n", handler.Header)

	// upload file to s3
	// _, error = s3Client.PutObject(context.TODO(), &s3.PutObjectInput{
	// 	Bucket: aws.String("cdk-entest-videos"),
	// 	Key:    aws.String("golang/" + handler.Filename),
	// 	Body:   file,
	// })

	// if error != nil {
	// 	fmt.Println("error upload s3")
	// }

	// Create file
	dest, error := os.Create("./static/" + handler.Filename)
	if error != nil {
		return
	}
	defer dest.Close()

	// Copy uploaded file to dest
	if _, err := io.Copy(dest, file); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// create a record in database
	db.Create(&Book{
		Title:       "Database Internals",
		Author:      "Hai Tran",
		Description: "Hello",
		Image:       handler.Filename,
	})

	fmt.Fprintf(w, "Successfully Uploaded File\n")

}

// promt format
const claudePromptFormat = "\n\nHuman: %s\n\nAssistant:"

// bedrock runtime client
var brc *bedrockruntime.Client

// init bedorck credentials connecting to aws
func init() {

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}

	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	if err != nil {
		log.Fatal(err)
	}

	brc = bedrockruntime.NewFromConfig(cfg)
}

// bedrock handler request
func bedrock(w http.ResponseWriter, r *http.Request) {

	var query Query
	var message string

	// parse mesage from request
	error := json.NewDecoder(r.Body).Decode(&query)

	if error != nil {
		message = "how to learn japanese as quick as possible?"
		panic(error)
	}

	message = query.Topic

	fmt.Println(message)

	prompt := "" + fmt.Sprintf(claudePromptFormat, message)

	payload := Request{
		Prompt:            prompt,
		MaxTokensToSample: 2048,
	}

	payloadBytes, error := json.Marshal(payload)

	if error != nil {
		fmt.Fprintf(w, "ERROR")
		// return "", error
	}

	output, error := brc.InvokeModelWithResponseStream(
		context.Background(),
		&bedrockruntime.InvokeModelWithResponseStreamInput{
			Body:        payloadBytes,
			ModelId:     aws.String("anthropic.claude-v2"),
			ContentType: aws.String("application/json"),
		},
	)

	if error != nil {
		fmt.Fprintf(w, "ERROR")
		// return "", error
	}

	for event := range output.GetStream().Events() {
		switch v := event.(type) {
		case *types.ResponseStreamMemberChunk:

			//fmt.Println("payload", string(v.Value.Bytes))

			var resp Response
			err := json.NewDecoder(bytes.NewReader(v.Value.Bytes)).Decode(&resp)
			if err != nil {
				fmt.Fprintf(w, "ERROR")
				// return "", err
			}

			fmt.Println(resp.Completion)

			fmt.Fprintf(w, resp.Completion)
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			} else {
				fmt.Println("Damn, no flush")
			}

		case *types.UnknownUnionMember:
			fmt.Println("unknown tag:", v.Tag)

		default:
			fmt.Println("union is nil or unknown type")
		}
	}
}

type Request struct {
	Prompt            string   `json:"prompt"`
	MaxTokensToSample int      `json:"max_tokens_to_sample"`
	Temperature       float64  `json:"temperature,omitempty"`
	TopP              float64  `json:"top_p,omitempty"`
	TopK              int      `json:"top_k,omitempty"`
	StopSequences     []string `json:"stop_sequences,omitempty"`
}

type Response struct {
	Completion string `json:"completion"`
}

type HelloHandler struct{}

type Query struct {
	Topic string `json:"topic"`
}
```

</details>

The static book page

<details>
<summary>index.html</summary>

```html
<!DOCTYPE html>
<!-- entest 29 april 2023 basic tailwind -->
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link
      href="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/review-book.css"
      rel="stylesheet"
    />
  </head>
  <body class="bg-gray-100">
    <div class="bg-green-400 py-3">
      <nav class="flex mx-auto max-w-5xl justify-between">
        <a href="#" class="font-bold text-2xl"> Entest </a>
        <ul class="hidden md:flex gap-x-3">
          <li
            class="bg-white hover:bg-green-600 hover:text-white px-3 py-1 rounded-sm"
          >
            <a href="https://cdk.entest.io/" target="_blank">About Me</a>
          </li>
        </ul>
      </nav>
    </div>
    <div
      class="bg-[url('https://d2cvlmmg8c0xrp.cloudfront.net/web-css/singapore.jpg')] bg-no-repeat bg-cover"
    >
      <div class="mx-auto max-w-5xl pt-20 pb-48 pr-48 mb-10 text-right">
        <h2 class="invisible md:visible text-3xl font-bold mb-8">
          Good Books about AWS Cloud Computing
        </h2>
      </div>
    </div>
    <div class="mx-auto max-w-5xl">
      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Data Engineering with AWS</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/data_engineering_with_aws.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            This is a great book for understanding and implementing the lake
            house architecture to integrate your Data Lake with your warehouse.
            It shows you all the steps you need to orchestrate your data
            pipeline. From architecture, ingestion, and processing to running
            queries in your data warehouse, I really like the very hands-on
            approach that shows you how you can immediately implement the topics
            in your AWS account Andreas Kretz, CEO, Learn Data Engineering
          </p>
          <a
            href="https://www.amazon.com/Data-Engineering-AWS-Gareth-Eagar/dp/1800560419/ref=sr_1_1?crid=28BFB3NXGTM9G&amp;keywords=data+engineering+with+aws&amp;qid=1682772617&amp;sprefix=data+engineering+with+aws%2Caps%2C485&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Data Science on AWS</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/data_science_on_aws.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            With this practical book, AI and machine learning practitioners will
            learn how to successfully build and deploy data science projects on
            Amazon Web Services. The Amazon AI and machine learning stack
            unifies data science, data engineering, and application development
            to help level up your skills. This guide shows you how to build and
            run pipelines in the cloud, then integrate the results into
            applications in minutes instead of days. Throughout the book,
            authors Chris Fregly and Antje Barth demonstrate how to reduce cost
            and improve performance.
          </p>
          <a
            href="https://www.amazon.com/Data-Science-AWS-End-End/dp/1492079391/ref=sr_1_1?crid=17XK1VLHDZH59&amp;keywords=data+science+on+aws&amp;qid=1682772629&amp;sprefix=data+science+on+%2Caps%2C327&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Serverless Analytics with Amazon Athena
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/serverless_athena.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            This book begins with an overview of the serverless analytics
            experience offered by Athena and teaches you how to build and tune
            an S3 Data Lake using Athena, including how to structure your tables
            using open-source file formats like Parquet. You willl learn how to
            build, secure, and connect to a data lake with Athena and Lake
            Formation. Next, you will cover key tasks such as ad hoc data
            analysis, working with ETL pipelines, monitoring and alerting KPI
            breaches using CloudWatch Metrics, running customizable connectors
            with AWS Lambda, and more. Moving on, you will work through easy
            integrations, troubleshooting and tuning common Athena issues, and
            the most common reasons for query failure.You will also review tips
            to help diagnose and correct failing queries in your pursuit of
            operational excellence.Finally, you will explore advanced concepts
            such as Athena Query Federation and Athena ML to generate powerful
            insights without needing to touch a single server.
          </p>
          <a
            href="https://www.amazon.com/Serverless-Analytics-Amazon-Athena-semi-structured/dp/1800562349/ref=sr_1_1?crid=2KSTZBI4HUBZS&amp;keywords=serverless+athena&amp;qid=1682772648&amp;sprefix=serverless+athe%2Caps%2C323&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Serverless ETL and Analytics with AWS Glue
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/serverless_glue.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            Beginning with AWS Glue basics, this book teaches you how to perform
            various aspects of data analysis such as ad hoc queries, data
            visualization, and real time analysis using this service. It also
            provides a walk-through of CI/CD for AWS Glue and how to shift left
            on quality using automated regression tests. You will find out how
            data security aspects such as access control, encryption, auditing,
            and networking are implemented, as well as getting to grips with
            useful techniques such as picking the right file format,
            compression, partitioning, and bucketing.As you advance, you will
            discover AWS Glue features such as crawlers, Lake Formation,
            governed tables, lineage, DataBrew, Glue Studio, and custom
            connectors. The concluding chapters help you to understand various
            performance tuning, troubleshooting, and monitoring options.
          </p>
          <a
            href="https://www.amazon.com/Serverless-ETL-Analytics-Glue-comprehensive/dp/1800564988/ref=sr_1_1?crid=HJXN5QBY7F2P&amp;keywords=serverless+ETL+with+glue+aws&amp;qid=1682772669&amp;sprefix=serverless+etl+with+glue+a%2Caps%2C324&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Simplify Big Data Analytics with Amazon EMR
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/amazon_emr.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Amazon EMR, formerly Amazon Elastic MapReduce, provides a managed
            Hadoop cluster in Amazon Web Services (AWS) that you can use to
            implement batch or streaming data pipelines. By gaining expertise in
            Amazon EMR, you can design and implement data analytics pipelines
            with persistent or transient EMR clusters in AWS.This book is a
            practical guide to Amazon EMR for building data pipelines. You will
            start by understanding the Amazon EMR architecture, cluster nodes,
            features, and deployment options, along with their pricing. Next,
            the book covers the various big data applications that EMR supports.
            You will then focus on the advanced configuration of EMR
            applications, hardware, networking, security, troubleshooting,
            logging, and the different SDKs and APIs it provides. Later chapters
            will show you how to implement common Amazon EMR use cases,
            including batch ETL with Spark, real time streaming with Spark
            Streaming, and handling UPSERT in S3 Data Lake with Apache Hudi.
            Finally, you will orchestrate your EMR jobs and strategize on
            premises Hadoop cluster migration to EMR. In addition to this, you
            will explore best practices and cost optimization techniques while
            implementing your data analytics pipeline in EMR
          </p>
          <a
            href="https://www.amazon.com/Simplify-Big-Data-Analytics-Amazon/dp/1801071071/ref=sr_1_1?crid=1BHYUKJ14LKNU&amp;keywords=%22Simplify+Big+Data+Analytics+with+Amazon+EMR&amp;qid=1682772695&amp;sprefix=simplify+big+data+analytics+with+amazon+emr%2Caps%2C322&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Scalable Data Streaming with Amazon Kinesis
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/amazon_kinesis.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            Amazon Kinesis is a collection of secure, serverless, durable, and
            highly available purpose built data streaming services. This data
            streaming service provides APIs and client SDKs that enable you to
            produce and consume data at scale. Scalable Data Streaming with
            Amazon Kinesis begins with a quick overview of the core concepts of
            data streams, along with the essentials of the AWS Kinesis
            landscape. You will then explore the requirements of the use case
            shown through the book to help you get started and cover the key
            pain points encountered in the data stream life cycle. As you
            advance, you will get to grips with the architectural components of
            Kinesis, understand how they are configured to build data pipelines,
            and delve into the applications that connect to them for consumption
            and processing. You will also build a Kinesis data pipeline from
            scratch and learn how to implement and apply practical solutions.
            Moving on, you will learn how to configure Kinesis on a cloud
            platform. Finally, you will learn how other AWS services can be
            integrated into Kinesis. These services include Redshift, Dynamo
            Database, AWS S3, Elastic Search, and third-party applications such
            as Splunk.
          </p>
          <a
            href="https://www.amazon.com/Scalable-Data-Streaming-Amazon-Kinesis/dp/1800565402/ref=sr_1_1?crid=1CC6W33MEW2GE&amp;keywords=Scalable+Data+Streaming+with+Amazon+Kinesis&amp;qid=1682772706&amp;sprefix=scalable+data+streaming+with+amazon+kinesis%2Caps%2C312&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Actionable Insights with Amazon QuickSight
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/amazon_quicksight.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Amazon Quicksight is an exciting new visualization that rivals
            PowerBI and Tableau, bringing several exciting features to the table
            but sadly, there are not many resources out there that can help you
            learn the ropes. This book seeks to remedy that with the help of an
            AWS certified expert who will help you leverage its full
            capabilities. After learning QuickSight is fundamental concepts and
            how to configure data sources, you will be introduced to the main
            analysis-building functionality of QuickSight to develop visuals and
            dashboards, and explore how to develop and share interactive
            dashboards with parameters and on screen controls. You will dive
            into advanced filtering options with URL actions before learning how
            to set up alerts and scheduled reports.
          </p>
          <a
            href="https://www.amazon.com/Actionable-Insights-Amazon-QuickSight-learning-driven/dp/1801079293/ref=sr_1_1?crid=1F6H7KDE97RHA&amp;keywords=Actionable+Insights+with+Amazon+QuickSight&amp;qid=1682772719&amp;sprefix=actionable+insights+with+amazon+quicksight%2Caps%2C305&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Amazon Redshift Cookbook</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/redshift_cook_book.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            Amazon Redshift is a fully managed, petabyte-scale AWS cloud data
            warehousing service. It enables you to build new data warehouse
            workloads on AWS and migrate on-premises traditional data
            warehousing platforms to Redshift. This book on Amazon Redshift
            starts by focusing on Redshift architecture, showing you how to
            perform database administration tasks on Redshift.You will then
            learn how to optimize your data warehouse to quickly execute complex
            analytic queries against very large datasets. Because of the massive
            amount of data involved in data warehousing, designing your database
            for analytical processing lets you take full advantage of Redshifts
            columnar architecture and managed services.As you advance, you will
            discover how to deploy fully automated and highly scalable extract,
            transform, and load (ETL) processes, which help minimize the
            operational efforts that you have to invest in managing regular ETL
            pipelines and ensure the timely and accurate refreshing of your data
            warehouse. Finally, you will gain a clear understanding of Redshift
            use cases, data ingestion, data management, security, and scaling so
            that you can build a scalable data warehouse platform.
          </p>
          <a
            href="https://www.amazon.com/Amazon-Redshift-Cookbook-warehousing-solutions/dp/1800569688/ref=sr_1_1?crid=2P8V7A8548HBG&amp;keywords=Amazon+Redshift+Cookbook&amp;qid=1682772732&amp;sprefix=amazon+redshift+cookbook%2Caps%2C315&amp;sr=8-1&amp;ufe=app_do%3Aamzn1.fos.006c50ae-5d4c-4777-9bc0-4513d670b6bc"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Automated Machine Learning on AWS</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/automated_ml_on_aws.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Automated Machine Learning on AWS begins with a quick overview of
            what the machine learning pipeline/process looks like and highlights
            the typical challenges that you may face when building a pipeline.
            Throughout the book, you&#39;ll become well versed with various AWS
            solutions such as Amazon SageMaker Autopilot, AutoGluon, and AWS
            Step Functions to automate an end-to-end ML process with the help of
            hands-on examples. The book will show you how to build, monitor, and
            execute a CI/CD pipeline for the ML process and how the various
            CI/CD services within AWS can be applied to a use case with the
            Cloud Development Kit (CDK). You&#39;ll understand what a
            data-centric ML process is by working with the Amazon Managed
            Services for Apache Airflow and then build a managed Airflow
            environment. You&#39;ll also cover the key success criteria for an
            MLSDLC implementation and the process of creating a self-mutating
            CI/CD pipeline using AWS CDK from the perspective of the platform
            engineering team
          </p>
          <a
            href="https://www.amazon.com/Automated-Machine-Learning-AWS-production-ready/dp/1801811822/ref=sr_1_1?crid=30X8QQER05M37&amp;keywords=Automated+Machine+Learning+on+AWS&amp;qid=1682772744&amp;sprefix=automated+machine+learning+on+aws%2Caps%2C327&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Kubernetes Up and Running</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/kubernetes_up_running.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            In just five years, Kubernetes has radically changed the way
            developers and ops personnel build, deploy, and maintain
            applications in the cloud. With this book is updated third edition,
            you will learn how this popular container orchestrator can help your
            company achieve new levels of velocity, agility, reliability, and
            efficiency whether you are new to distributed systems or have been
            deploying cloud native apps for some time.
          </p>
          <a
            href="https://www.amazon.com/Kubernetes-Running-Dive-Future-Infrastructure/dp/109811020X/ref=sr_1_1?crid=2H4E57L24G3C5&amp;keywords=Kubernetes+Up+and+Running&amp;qid=1682772756&amp;sprefix=kubernetes+up+and+running%2Caps%2C332&amp;sr=8-1&amp;ufe=app_do%3Aamzn1.fos.006c50ae-5d4c-4777-9bc0-4513d670b6bc"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Getting Started with Containerization</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/containerization.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Kubernetes is an open source orchestration platform for managing
            containers in a cluster environment. This Learning Path introduces
            you to the world of containerization, in addition to providing you
            with an overview of Docker fundamentals. As you progress, you will
            be able to understand how Kubernetes works with containers. Starting
            with creating Kubernetes clusters and running applications with
            proper authentication and authorization, you will learn how to
            create high- availability Kubernetes clusters on Amazon Web
            Services(AWS), and also learn how to use kubeconfig to manage
            different clusters.Whether it is learning about Docker containers
            and Docker Compose, or building a continuous delivery pipeline for
            your application, this Learning Path will equip you with all the
            right tools and techniques to get started with containerization.
          </p>
          <a
            href="https://www.amazon.com/Getting-Started-Containerization-operational-automating-ebook/dp/B07Q4952SH/ref=sr_1_1?crid=3PUMFFKQW7EG6&amp;keywords=getting+started+with+containerization&amp;qid=1682772768&amp;sprefix=getting+started+with+containerizatio%2Caps%2C318&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Production Kubernetes</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/singapore.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            Kubernetes has become the dominant container orchestrator, but many
            organizations that have recently adopted this system are still
            struggling to run actual production workloads. In this practical
            book, four software engineers from VMware bring their shared
            experiences running Kubernetes in production and provide insight on
            key challenges and best practices. The brilliance of Kubernetes is
            how configurable and extensible the system is, from pluggable
            runtimes to storage integrations. For platform engineers, software
            developers, infosec, network engineers, storage engineers, and
            others, this book examines how the path to success with Kubernetes
            involves a variety of technology, pattern, and abstraction
            considerations.
          </p>
          <a
            href="https://www.amazon.com/Production-Kubernetes-Successful-Application-Platforms/dp/B0C2JG8HN4/ref=sr_1_1?crid=2VL6HBN63YSKR&amp;keywords=Production+Kubernetes&amp;qid=1682772779&amp;sprefix=production+kubernetes%2Caps%2C320&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Practical Vim</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/practical_vim.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Vim is a fast and efficient text editor that will make you a faster
            and more efficient developer. It&#39;s available on almost every OS,
            and if you master the techniques in this book, you will never need
            another text editor. In more than 120 Vim tips, you will quickly
            learn the editor&#39;s core functionality and tackle your trickiest
            editing and writing tasks. This beloved bestseller has been revised
            and updated to Vim 8 and includes three brand-new tips and five
            fully revised tips.
          </p>
          <a
            href="https://www.amazon.com/Practical-Vim-Edit-Speed-Thought/dp/1680501275/ref=sr_1_1?crid=37R58M1VK37ED&amp;keywords=Practical+Vim&amp;qid=1682772791&amp;s=audible&amp;sprefix=practical+vim%2Caudible%2C304&amp;sr=1-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">CSS In Depth</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/css_in_depth.jpeg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            CSS in Depth exposes you to a world of CSS techniques that range
            from clever to mind-blowing. This instantly useful book is packed
            with creative examples and powerful best practices that will sharpen
            your technical skills and inspire your sense of design.
          </p>
          <a
            href="https://www.amazon.com/CSS-Depth-Keith-J-Grant/dp/1617293458/ref=sr_1_1?crid=SRUEMD3CZ94C&amp;keywords=CSS+In+Depth&amp;qid=1682772805&amp;sprefix=css+in+depth%2Caps%2C326&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Effective Typescript</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/effective_typescript.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            TypeScript is a typed superset of JavaScript with the potential to
            solve many of the headaches for which JavaScript is famous. But
            TypeScript has a learning curve of its own, and understanding how to
            use it effectively can take time. This book guides you through 62
            specific ways to improve your use of TypeScript
          </p>
          <a
            href="https://www.amazon.com/Effective-TypeScript-Specific-Ways-Improve/dp/1492053740/ref=sr_1_1?crid=1BPGNPZ1QMNOI&amp;keywords=%22Effective+Typescript&amp;qid=1682772816&amp;sprefix=effective+typescript%2Caps%2C318&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">
            Unix and Linux System Administration Handbook
          </h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/unix_linux_admin.jpeg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            UNIX and Linux System Administration Handbook, Fifth Edition, is
            today definitive guide to installing, configuring, and maintaining
            any UNIX or Linux system, including systems that supply core
            Internet and cloud infrastructure. Updated for new distributions and
            cloud environments, this comprehensive guide covers best practices
            for every facet of system administration, including storage
            management, network design and administration, security, web
            hosting, automation, configuration management, performance analysis,
            virtualization, DNS, security, and the management of IT service
            organizations. The authors―world-class, hands-on technologists―offer
            indispensable new coverage of cloud platforms, the DevOps
            philosophy, continuous deployment, containerization, monitoring, and
            many other essential topics.Whatever your role in running systems
            and networks built on UNIX or Linux, this conversational,
            well-written ¿guide will improve your efficiency and help solve your
            knottiest problems.
          </p>
          <a
            href="https://www.amazon.com/UNIX-Linux-System-Administration-Handbook/dp/0134277554/ref=sr_1_1?crid=1HWI8UE6KJ6PT&amp;keywords=Unix+and+Linux+System+Administration+Handbook&amp;qid=1682772831&amp;sprefix=unix+and+linux+system+administration+handbook%2Caps%2C320&amp;sr=8-1"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>

      <div class="md:flex gap-x-5 flex-row mb-8">
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Computer Organization and Design</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/computer_organization.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p>
            Computer Organization and Design, Fifth Edition, is the latest
            update to the classic introduction to computer organization. The
            text now contains new examples and material highlighting the
            emergence of mobile computing and the cloud. It explores this
            generational change with updated content featuring tablet computers,
            cloud infrastructure, and the ARM (mobile computing devices) and x86
            (cloud computing) architectures. The book uses a MIPS processor core
            to present the fundamentals of hardware technologies, assembly
            language, computer arithmetic, pipelining, memory hierarchies and
            I/Because an understanding of modern hardware is essential to
            achieving good performance and energy efficiency, this edition adds
            a new concrete example, Going Faster, used throughout the text to
            demonstrate extremely effective optimization techniques. There is
            also a new discussion of the Eight Great Ideas of computer
            architecture. Parallelism is examined in depth with examples and
            content highlighting parallel hardware and software topics. The book
            features the Intel Core i7, ARM Cortex A8 and NVIDIA Fermi GPU as
            real world examples, along with a full set of updated and improved
            exercises.
          </p>
          <a
            href="https://www.amazon.com/Computer-Organization-Design-RISC-V-Architecture/dp/0128203315/ref=sr_1_1?crid=2SWQJ2EPAWKZT&amp;keywords=Computer+Organization+and+Design&amp;qid=1682772842&amp;sprefix=computer+organization+and+design%2Caps%2C329&amp;sr=8-1&amp;ufe=app_do%3Aamzn1.fos.006c50ae-5d4c-4777-9bc0-4513d670b6bc"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
        <div class="ml-4 bg-white flex-auto w-full">
          <h4 class="font-bold mb-8">Database Systems The Complete Book</h4>
          <div>
            <img
              src="https://d2cvlmmg8c0xrp.cloudfront.net/web-css/database_system.jpg"
              class="float-left h-auto w-64 mr-6"
              alt="book-image"
            />
          </div>
          <p></p>
          <p>
            Database Systems: The Complete Book is ideal for Database Systems
            and Database Design and Application courses offered at the junior,
            senior and graduate levels in Computer Science departments. A basic
            understanding of algebraic expressions and laws, logic, basic data
            structure, OOP concepts, and programming environments is implied.
            Written by well-known computer scientists, this introduction to
            database systems offers a comprehensive approach, focusing on
            database design, database use, and implementation of database
            applications and database management systems.
          </p>
          <a
            href="https://www.amazon.com/Database-Systems-Complete-Book-2nd/dp/0131873253/ref=sr_1_1?crid=3E1GPJPYRNH9Z&amp;keywords=Database+Systems+The+Complete+Book&amp;qid=1682772851&amp;sprefix=database+systems+the+complete+book%2Caps%2C336&amp;sr=8-1&amp;ufe=app_do%3Aamzn1.fos.f5122f16-c3e8-4386-bf32-63e904010ad0"
            target="_blank"
          >
            <button
              class="bg-orange-300 px-14 py-3 rounded-md shadow-md hover:bg-orange-400"
            >
              Amazon
            </button>
          </a>
        </div>
      </div>
    </div>
    <footer class="bg-gray-200 mt-12 text-gray-00 py-4">
      <div class="mx-auto max-w-5xl text-center text-base">
        Copyright &copy; 2023 entest, Inc
      </div>
    </footer>
  </body>
</html>
```

</details>

The postgresql page

<details>
<summary>book-template.html</summary>

```html
<html>
  <head>
    <style>
      .body {
        background-color: antiquewhite;
      }

      .container {
        max-width: 800px;
        margin-left: auto;
        margin-right: auto;
      }

      .title {
        font: bold;
        margin-bottom: 8px;
      }

      .image {
        float: left;
        height: auto;
        width: 128px;
        margin-right: 6px;
      }

      .card {
        margin-left: 4px;
        margin-right: 4px;
        background-color: white;
        width: 100%;
      }

      .grid {
        display: grid;
        row-gap: 10px;
        column-gap: 10px;
        grid-template-columns: repeat(1, minmax(0, 1fr));
      }

      @media (min-width: 35em) {
        .grid {
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }
      }
    </style>
  </head>
  <body class="body">
    <div class="container">
      <div class="grid">
        {{range $book:= .}}
        <div class="card">
          <h4 class="title">{{ $book.Image}}</h4>
          <h4 class="title">{{ $book.Author }}</h4>
          <img src="/demo/{{ $book.Image }}" alt="book-image" class="image" />
          <p>
            Lorem ipsum dolor sit amet consectetur, adipisicing elit. Rem
            quaerat quas corrupti cum blanditiis, sint non officiis minus
            molestiae culpa consectetur ex voluptatibus distinctio ipsam.
            Possimus sint voluptatum at modi! Lorem ipsum, dolor sit amet
            consectetur adipisicing elit. Alias dolore soluta error adipisci
            eius pariatur laborum sed impedit. Placeat minus aut perspiciatis
            dolor veniam, dolores odio sint eveniet? Numquam, tenetur! Lorem
            ipsum dolor sit amet consectetur adipisicing elit. Earum suscipit
            porro animi! Ducimus maiores et non. Minima nostrum ipsa voluptas
            assumenda consequuntur dicta reprehenderit numquam similique,
            nesciunt officiis facere optio. {{ $book.Description}}
          </p>
        </div>
        {{end}}
      </div>
    </div>
  </body>
</html>
```

</details>

Most simple webserver which only serving a static page

```go
package main

import (
	"net/http"
	"time"
)

func main ()  {

	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// fmt.Fprintf(w, "Hello Minh Tran")
		http.ServeFile(w, r, "index.html")
	})

	server := &http.Server{
		Addr: ":3000",
		Handler: mux,
		ReadTimeout: 10 * time.Second,
		WriteTimeout: 10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	server.ListenAndServe()
}
```

## Basic Vimc

This is a basic vimrc

```go
" tab width
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set cindent
set autoindent
set smartindent
set mouse=a
set hlsearch
set showcmd
set title
set expandtab
set incsearch

" line number
set number
hi CursorLineNr cterm=None

" highlight current line
set cursorline
hi CursorLine cterm=NONE ctermbg=23  guibg=Grey40

" change cursor between modes
let &t_SI = "\e[6 q"
let &t_EI = "\e[2 q"

" netrw wsize
let g:netrw_liststyle=3
let g:netrw_keepdir=0
let g:netrw_winsize=30
map <C-a> : Lexplore<CR>

" per default, netrw leaves unmodified buffers open.  This autocommand
" deletes netrw's buffer once it's hidden (using ':q;, for example)
autocmd FileType netrw setl bufhidden=delete  " or use :qa!

" these next three lines are for the fuzzy search:
set nocompatible      "Limit search to your project
set path+=**          "Search all subdirectories and recursively
set wildmenu          "Shows multiple matches on one line

" highlight syntax
set re=0
syntax on

" colorscheme
colorscheme desert
```

## Deploy

- Using UserData
- User Docker

Here is UserData

```go
#!/bin/bash
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
tar -xvf go1.21.5.linux-amd64.tar.gz
wget https://github.com/cdk-entest/go-web-demo/archive/refs/heads/main.zip
unzip main
cd go-web-demo-main/
./entest &
```

Here is Dockerfile

```go
# syntax=docker/dockerfile:1

# Build the application from source
FROM golang:1.21.5 AS build-stage

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /entest

# Run the tests in the container
FROM build-stage AS run-test-stage

# Deploy the application binary into a lean image
FROM gcr.io/distroless/base-debian11 AS build-release-stage

WORKDIR /

COPY --from=build-stage /entest /entest
COPY *.html ./
COPY static ./static

EXPOSE 3000

USER nonroot:nonroot

ENTRYPOINT ["/entest"]
```

And a buildscript in python

```py
import os

# parameters
REGION = "us-east-1"
ACCOUNT = os.environ["ACCOUNT_ID"]

# delete all docker images
os.system("sudo docker system prune -a")

# build go-app image
os.system("sudo docker build -t go-app . ")

#  aws ecr login
os.system(f"aws ecr get-login-password --region {REGION} | sudo docker login --username AWS --password-stdin {ACCOUNT}.dkr.ecr.{REGION}.amazonaws.com")

# get image id
IMAGE_ID=os.popen("sudo docker images -q go-app:latest").read()

# tag go-app image
os.system(f"sudo docker tag {IMAGE_ID.strip()} {ACCOUNT}.dkr.ecr.{REGION}.amazonaws.com/go-app:latest")

# create ecr repository
os.system(f"aws ecr create-repository --registry-id {ACCOUNT} --repository-name go-app")

# push image to ecr
os.system(f"sudo docker push {ACCOUNT}.dkr.ecr.{REGION}.amazonaws.com/go-app:latest")

# run locally to test
# os.system(f"sudo docker run -d -p 3000:3000 go-app:latest")
```
