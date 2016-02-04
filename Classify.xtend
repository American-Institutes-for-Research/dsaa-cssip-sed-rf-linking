package rf

import java.io.FileInputStream
import java.nio.file.Files
import java.nio.file.Paths
import java.util.ArrayList
import java.util.HashMap
import java.util.LinkedList
import java.util.List
import org.apache.commons.csv.CSVFormat
import org.apache.commons.csv.CSVPrinter
import weka.classifiers.trees.RandomForest
import weka.core.DenseInstance
import weka.core.SerializationHelper
import weka.core.converters.ConverterUtils.DataSource

class Classify {
	
	val public static UNIVERSITIES = newHashMap(
		"OSU" -> "SED1",
		"Purdue" -> "SED2",
		"UWisconsin" -> "SED3",
		"UMN" -> "SED4",
		"UIowa" -> "SED5"
		"UChicago" -> "SED6"
		"UMich" -> "SED7",
		"UIndiana" -> "SED8"
		"PSU" -> "SED9",
		"Caltech" -> "SED10"
	)
	
	val static MATCH_CLASS = 3
	
	def static void main(String... args) {
		println("Load random forest model...")
		val loadPath = Paths.get(TrainingData::WORKING_DIR, "model.obj") 
		val forest = SerializationHelper::read(new FileInputStream(loadPath.toString)) as RandomForest
		
		val outputFields = new LinkedList(Database::umetricsFields.keySet)
		outputFields.addAll(Database::sedFields.keySet)
		outputFields.addAll(RecordComparison::FieldNames)
		
		for (level: 0..ModelInputFile::MAX_LEVEL)
			outputFields.add(String.format("%s-%d", ModelInputFile::RELATION, level))
		
		val String[] headerArray = newArrayOfSize(outputFields.size)
		var ix = 0
		for (field: outputFields)
			headerArray.set(ix++, field)
			
		println("Load name frequencies...")
		val firstNames = new HashMap<String, Double>
		val lastNames = new HashMap<String, Double>
		TrainingData::readNameFrequencyFiles(firstNames, lastNames)
		
		println("Load variable means...")
		val means = readMeans
		
		val cmp = new RecordComparison(means, firstNames, lastNames)
		
		val cls = new Classify(forest, cmp)
		val db = new Database("localhost", "user", "password")
		
		UNIVERSITIES.entrySet.parallelStream.forEach[entry|
			val university = entry.key
			val phdinst = entry.value
			
			val linkPath = Paths.get(TrainingData::WORKING_DIR, String.format("links_%s.csv", university))
			val pr = CSVFormat::EXCEL.withHeader(headerArray).print(Files.newBufferedWriter(linkPath))
			
			val umetrics = new ArrayList<Row>(db.getUmetrics(#[university]).values)
			val sed = new ArrayList<Row>(db.getSed(#[phdinst]).values)
			
			System.out.format("Classifying %s...\n", university)
			cls.classifyUniversity(umetrics, sed, pr)
			System.out.format("Finished %s.\n", university)
			
			pr.flush
			pr.close			
		]
		
		println("DONE")
	}
	
	def static readMeans() {
		val path = Paths.get(TrainingData::WORKING_DIR, "means.csv")
		val csv = CSVFormat::EXCEL.withHeader.parse(Files.newBufferedReader(path))
		val result = new HashMap<String, Double>
		
		for (rec: csv)
			result.put(rec.get("attribute"), Double::parseDouble(rec.get("value")))
			
		result
	}
	
	new(
		RandomForest forest, 
		RecordComparison cmp
	) {
		this.forest = forest
		this.cmp = cmp
	}
	
	def classifyUniversity(
		List<Row> umetrics, 
		List<Row> sed, 
		CSVPrinter pr
	) {

		val buf = newDoubleArrayOfSize(RecordComparison::NUM_COMPARISONS)
		
		// this loop reads the dummy ARFF file and adds cases one by one to it for inference
		// it seems like there should be an easier way to create a data set for inference in
		// memory, but I wasn't able to find it
		
		for (um: umetrics) {
			val path = Paths.get(TrainingData::WORKING_DIR, "dummy.arff")
			val source = new DataSource(path.toString)
			var data = source.dataSet
			data.classIndex = data.numAttributes - 1
			
			for (s: sed) {
				cmp.compare(um, s, buf, true)
				val inst = new DenseInstance(1.0, buf)
				
				data.add(inst)
				val dist = forest.distributionForInstance(data.lastInstance)
				
				if (dist.get(4) + dist.get(3) >= 0.2) {
					val result = new LinkedList<String>
					result.addAll(um)
					result.addAll(s)
					result.addAll(RecordComparison::toStrings(buf))
					result.addAll(RecordComparison::toStrings(dist))
					pr.printRecord(result)
				}
				
			}
		}
	}
	
	val RecordComparison cmp
	val RandomForest forest
}