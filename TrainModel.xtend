package rf

import java.nio.file.Files
import java.nio.file.Paths
import org.apache.commons.csv.CSVFormat
import weka.classifiers.trees.RandomForest
import weka.core.SerializationHelper
import weka.core.converters.ConverterUtils.DataSource
import weka.filters.Filter
import weka.filters.unsupervised.attribute.ReplaceMissingValues

class TrainModel {
	def static void main(String... args) {
		println("Loading and filtering data...")
		
		val path = Paths.get(TrainingData::WORKING_DIR, "training_data.arff")
		val source = new DataSource(path.toString)
		var data = source.dataSet
		data.classIndex = data.numAttributes - 1
		
		val replace = new ReplaceMissingValues
		replace.inputFormat = data
		data = Filter::useFilter(data, replace)
		
		println("Save means and modes from training data...")
		val means = Paths.get(TrainingData::WORKING_DIR, "means.csv")
		val pr = CSVFormat::EXCEL.withHeader("attribute","value").print(Files.newBufferedWriter(means))
		
		for (i: 0 ..< data.numAttributes) {
			val attr = data.attribute(i)
			pr.printRecord(attr.name, data.meanOrMode(attr))
		}
		
		pr.flush
		pr.close
		
		println("Training classifier...")
		
		val forest = new RandomForest
		forest.buildClassifier(data)
		
		println(forest)
		
		val savePath = Paths.get(TrainingData::WORKING_DIR, "model.obj")
		SerializationHelper.write(savePath.toString, forest)
		
		println("DONE")
	}
}