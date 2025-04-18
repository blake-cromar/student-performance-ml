# Student Math Performance

This project leverages Azure Machine Learning Studio to predict the final grade (`G3`) of students based on a variety of academic and socio-demographic features from the math student performance dataset. The dataset includes attributes such as prior grades, study time, family background, and school-related factors.

To model the `G3` prediction problem, two distinct approaches within Azure ML Studio are used:
	1.	Automated ML (AutoML)
Using Azure’s AutoML, multiple models are automatically trained and evaluated to determine the best-performing regression model for predicting the `G3` column. AutoML handles feature selection, preprocessing, and algorithm tuning, streamlining the model selection process. The top-performing model is chosen based on evaluation metrics such as R² score and mean absolute error (MAE).
	2.	HyperDrive (Custom Training with Hyperparameter Tuning)
In contrast to AutoML, the second approach uses HyperDrive, which enables hyperparameter tuning on a custom-defined model. A regression model (FILL THIS IN LATER) is manually implemented and trained using a script. HyperDrive explores different combinations of hyperparameters to optimize the model’s performance, offering more control over the training pipeline.

This dual-method strategy allows for both automation and custom experimentation, offering insights into model performance and trade-offs between ease-of-use and manual fine-tuning.


## Project Set Up and Installation

Before running the script, make sure the accompanying `.env` file is properly configured. This file is used to provide environment-specific values that the deployment script will reference.

The `.env` file should include the following variables:

- **Azure Subscription Info**:
  - `SUBSCRIPTION_ID`: Your Azure subscription ID
  - `RESOURCE_GROUP`: The name of the resource group to create or use
  - `LOCATION`: The Azure region where resources will be deployed (e.g., `norwayeast`)

- **Azure ML Resource Names**:
  - `WORKSPACE_NAME`: The name of your Azure Machine Learning workspace
  - `STORAGE_ACCOUNT_NAME`: The name of the associated storage account (must be globally unique)

- **Compute Configuration**:
  - `COMPUTE_SIZE`: The VM size for the compute instance (e.g., `Standard_DS11_v2`)

Once the `.env` file has been updated with your values, run the following command in the terminal:

```bash
bash env-deployment.sh
```

NOTE: This process takes about 15 minutes.

## Dataset

### Overview
*TODO*: Explain about the data you are using and where you got it from.

### Task
*TODO*: Explain the task you are going to be solving with this dataset and the features you will be using for it.

### Access
*TODO*: Explain how you are accessing the data in your workspace.

## Automated ML
*TODO*: Give an overview of the `automl` settings and configuration you used for this experiment

### Results
*TODO*: What are the results you got with your automated ML model? What were the parameters of the model? How could you have improved it?

*TODO* Remeber to provide screenshots of the `RunDetails` widget as well as a screenshot of the best model trained with it's parameters.

## Hyperparameter Tuning
*TODO*: What kind of model did you choose for this experiment and why? Give an overview of the types of parameters and their ranges used for the hyperparameter search


### Results
*TODO*: What are the results you got with your model? What were the parameters of the model? How could you have improved it?

*TODO* Remeber to provide screenshots of the `RunDetails` widget as well as a screenshot of the best model trained with it's parameters.

## Model Deployment
*TODO*: Give an overview of the deployed model and instructions on how to query the endpoint with a sample input.

## Screen Recording
*TODO* Provide a link to a screen recording of the project in action. Remember that the screencast should demonstrate:
- A working model
- Demo of the deployed  model
- Demo of a sample request sent to the endpoint and its response

## Standout Suggestions
*TODO (Optional):* This is where you can provide information about any standout suggestions that you have attempted.

## Attributions

This project was developed with guidance and resources provided by [Udacity](https://www.udacity.com/) as part of the **Machine Learning Engineer with Microsoft Azure Nanodegree** program. Special thanks to the course instructors:

- **Erick Galinkin** – Principal AI Researcher at Rapid7  
- **Noah Gift** – Founder of Pragmatic AI Labs and expert in MLOps and Cloud Architecture  
- **Soham Chatterjee** – Graduate student focused on Edge Computing and IoT  
- **Alfredo Deza** – Software engineer, open-source developer, and former Olympic athlete  
## References

Additional reference material and implementation guidance were drawn from the following Microsoft Azure Machine Learning documentation:

- [How to configure automated ML training](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-auto-train?view=azureml-api-2&tabs=python)
- [RegressionJob class reference – Azure ML Python SDK](https://learn.microsoft.com/en-us/python/api/azure-ai-ml/azure.ai.ml.automl.regressionjob?view=azure-python&utm_source=chatgpt.com)
