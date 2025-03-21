# Student Math Performance

This project leverages Azure Machine Learning Studio to predict the final grade (`G3`) of students based on a variety of academic and socio-demographic features from the math student performance dataset. The dataset includes attributes such as prior grades, study time, family background, and school-related factors.

To model the `G3` prediction problem, two distinct approaches within Azure ML Studio are used:
	1.	Automated ML (AutoML)
Using Azure’s AutoML, multiple models are automatically trained and evaluated to determine the best-performing regression model for predicting the `G3` column. AutoML handles feature selection, preprocessing, and algorithm tuning, streamlining the model selection process. The top-performing model is chosen based on evaluation metrics such as R² score and mean absolute error (MAE).
	2.	HyperDrive (Custom Training with Hyperparameter Tuning)
In contrast to AutoML, the second approach uses HyperDrive, which enables hyperparameter tuning on a custom-defined model. A regression model (FILL THIS IN LATER) is manually implemented and trained using a script. HyperDrive explores different combinations of hyperparameters to optimize the model’s performance, offering more control over the training pipeline.

This dual-method strategy allows for both automation and custom experimentation, offering insights into model performance and trade-offs between ease-of-use and manual fine-tuning.


## Project Set Up and Installation

### Creating the Workspace
In the terminal navigate to the 

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
