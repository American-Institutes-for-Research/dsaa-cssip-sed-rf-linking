
The following files are contained in the `src` folder:

* TrainingData.xtend: load STAR METRICS and SED records from the database, compute record comparisons, and write the result to an output file. This is the file that determines the number of match levels included in the output and how they are defined. It also determines how many cases of each match level to compute and how to choose the cases to compute.
* TrainModel.xtend: Use weka to train a random forest model and serialize the resulting java object to a file.
* Classify.xtend: Load the model created by TrainModel.xtend and infer links on other universities
* Database.xtend: Database connectivity and functions for loading SED and STAR METRICS records
* ModelInputFile.xtend: Some utilities for writing ARFF files
* RecordComparison.xtend: Defines the actual set of comparisons and fields that are used by the random forest model
