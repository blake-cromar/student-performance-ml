import argparse
import pandas as pd
from azureml.core import Dataset
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error
from sklearn.preprocessing import LabelEncoder

# Function to load and preprocess the data from Azure ML
def load_and_preprocess_data(workspace):
    # Load the dataset from Azure ML workspace
    dataset = Dataset.get_by_name(workspace=workspace, name="student-math")
    df = dataset.to_pandas_dataframe()  # Convert the dataset to a pandas DataFrame
    
    # Separate target variable (G3) and features
    X = df.drop(columns=['G3'])
    y = df['G3']
    
    # Encode categorical features using LabelEncoder
    categorical_columns = X.select_dtypes(include=['object']).columns
    le = LabelEncoder()
    
    for col in categorical_columns:
        X[col] = le.fit_transform(X[col])
    
    return X, y

# Main function for training the model
def main():
    # Parse command-line arguments for hyperparameters
    parser = argparse.ArgumentParser()
    parser.add_argument('--n_estimators', type=int, default=100)
    parser.add_argument('--max_depth', type=int, default=10, choices=[3, 5, 10, None])
    parser.add_argument('--min_samples_split', type=float, default=0.2)
    parser.add_argument('--workspace', type=str, required=True)  # Add the workspace argument
    args = parser.parse_args()
    
    # Load and preprocess data from Azure ML
    X, y = load_and_preprocess_data(args.workspace)

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Initialize the model with hyperparameters
    model = RandomForestRegressor(n_estimators=args.n_estimators,
                                  max_depth=args.max_depth,
                                  min_samples_split=args.min_samples_split,
                                  random_state=42)
    
    # Train the model
    model.fit(X_train, y_train)
    
    # Make predictions on the test set
    y_pred = model.predict(X_test)
    
    # Evaluate the model using mean absolute error
    mae = mean_absolute_error(y_test, y_pred)
    print(f'Mean Absolute Error: {mae}')
    
    # Return the MAE for HyperDrive evaluation
    return mae

if __name__ == '__main__':
    main()