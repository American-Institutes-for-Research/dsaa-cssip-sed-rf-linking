package rf

import java.nio.file.Files
import java.nio.file.Paths
import java.util.ArrayList
import java.util.HashMap
import java.util.LinkedList
import java.util.List
import java.util.Map
import java.util.Random
import java.util.TreeMap
import org.apache.commons.csv.CSVFormat
import org.eclipse.xtend.lib.annotations.Data

import static extension java.lang.String.format

class TrainingData {
	val public static CLASS_CUTOFFS = newLinkedHashMap(14.0 -> 4, 8.2 -> 3, 6.0 -> 2, 0.0 -> 1)
	
	val public static WORKING_DIR = "/path/to/working"
	
	val static DOB_UNIVERSITIES = newHashMap(
		"OSU" -> "SED1",
		"Purdue" -> "SED2",
		"UWisconsin" -> "SED3"
	)
	
	def static void main(String... args) {
		trainingFileAll()
		//trainingFileForCrossvalidation()
	}
	
	/**
	 * Create the training file that uses data from all universities with DOB
	 */
	def static void trainingFileAll() {
		println("Load name frequencies...")
		val firstNames = new HashMap<String, Double>
		val lastNames = new HashMap<String, Double>
		readNameFrequencyFiles(firstNames, lastNames)
		
		val cmp = new RecordComparison(firstNames, lastNames)
		
		println("Load link file...")
		val links = readLinkFile("sed_sm_dob_matching_output_withoutevaldata.csv")
		
		println("Fetch UMETRICS records...")
		val db = new Database("localhost", "user", "password")
		val umetrics = db.getUmetrics(DOB_UNIVERSITIES.keySet)
		System.out.format("Got %d records\n", umetrics.size)
		
		println("Fetch SED records...")
		val sed = db.getSed(DOB_UNIVERSITIES.values) 
		System.out.format("Got %d records\n", sed.size)
		
		println("Create training data...")
		var path = Paths.get(WORKING_DIR, "training_data.arff")
		val file = new ModelInputFile(path, cmp.fieldNames)
		file.printHeader
		
		// write the match class
		writeComparisons(file, links.get(4), 4, umetrics, sed, cmp)
		writeComparisons(file, links.get(3), 3, umetrics, sed, cmp)
		
		val nMatches = links.get(3).size + links.get(4).size 
		
		// write the marginal nonmatch class -- constructed out of 2 match score ranges
		writeComparisons(file, links.get(2), 2, umetrics, sed, cmp)
		writeComparisons(file, links.get(1), 1, umetrics, sed, cmp, 3000)
		
		val allLinks = new LinkedList<Link>
		for (ll: links.values)
			allLinks.addAll(ll)
		
		writeRandomComparisons(file, allLinks, 0, umetrics, sed, cmp, 3000)
		
		file.close
		
		println("Create dummy ARFF file...")
		path = Paths.get(WORKING_DIR, "dummy.arff")
		val dummy = new ModelInputFile(path, cmp.fieldNames)
		dummy.printHeader
		dummy.close
		
		println("DONE")		
	}
	
	/**
	 * Create separate training files for each university for use in cross-validation.
	 */
	def static void trainingFileForCrossvalidation() {
		println("Load name frequencies...")
		val firstNames = new HashMap<String, Double>
		val lastNames = new HashMap<String, Double>
		readNameFrequencyFiles(firstNames, lastNames)
		
		val cmp = new RecordComparison(firstNames, lastNames)
		
		println("Load link file...")
		val links = readLinkFile("sed_sm_dob_matching_output.csv")
		
		val db = new Database("localhost", "user", "password")
		
		for (university: DOB_UNIVERSITIES.keySet) {
			println("Fetch UMETRICS records for %s...".format(university))
			val umetrics = db.getUmetrics(university)
			println("Got %d records".format(umetrics.size))
			
			println("Fetch SED records for %s".format(university))
			val phdinst = DOB_UNIVERSITIES.get(university)
			val sed = db.getSed(phdinst)
			println("Got %d records".format(sed.size))
			
			println("Create training data for %s...".format(university))
			val path = Paths.get(WORKING_DIR, "training_data_%s.arff".format(university))
			val file = new ModelInputFile(path, cmp.fieldNames)
			file.printHeader
			
			val uniLinks = new TreeMap<Integer, List<Link>>
			for (level: links.keySet) {
				val ll = links.get(level).filter[umetrics.containsKey(it.employeeId)].toList
				uniLinks.put(level, ll)
			}		
		
			for (i: 4..2) {
				val ll = uniLinks.get(i)
				writeComparisons(file, ll, i, umetrics, sed, cmp)
			}
				
			writeComparisons(file, uniLinks.get(1), 1, umetrics, sed, cmp, uniLinks.get(4).size)
			
			val allLinks = new LinkedList<Link>
			for (ll: uniLinks.values)
				allLinks.addAll(ll)
				
			writeRandomComparisons(file, allLinks, 0, umetrics, sed, cmp, uniLinks.get(4).size)
			file.close
		}
		
		println("DONE")			
	}
	
	@Data
	static class Link {
		val int employeeId
		val String drfId
	}
	
	def static label(double score) {
		for (entry: CLASS_CUTOFFS.entrySet) {
			if (score >= entry.key)
				return entry.value
		}
		
		return 0
	}
	
	def static readLinkFile(String file) {
		val path = Paths.get(WORKING_DIR, file)
		val csv = CSVFormat::EXCEL.withHeader.parse(Files.newBufferedReader(path))
		val links = new TreeMap<Integer, List<Link>>
		
		for (i: 0..4)
			links.put(i, new ArrayList<Link>)
		
		for (rec: csv) {
			val link = new Link(Integer::parseInt(rec.get("seq_1")), rec.get("seq_2"))
			val score = Double::parseDouble(rec.get("score"))
			links.get(label(score)).add(link)
		}
		
		links
	}
	
	def static readNameFrequencyFiles(
		Map<String, Double> firstNames,
		Map<String, Double> lastNames
	) {
		var path = Paths.get(WORKING_DIR, "first_name_frequency.csv")
		var in = Files.newBufferedReader(path)
		var csv = CSVFormat::EXCEL.withHeader.parse(in)
		
		for (rec: csv)
			firstNames.put(rec.get("first_name"), Double::parseDouble(rec.get("frequency")))
			
		csv.close
		
		path = Paths.get(WORKING_DIR, "last_name_frequency.csv")
		in = Files.newBufferedReader(path)
		csv = CSVFormat::EXCEL.withHeader.parse(in)
		
		for (rec: csv)
			lastNames.put(rec.get("last_name"), Double::parseDouble(rec.get("frequency")))
			
		csv.close
	}
	
	/**
	 * Create comparisons for all links in the list
	 */
	def static writeComparisons(
		ModelInputFile file, 
		List<Link> links, 
		int label,
		Map<Integer, Row> umetrics, 
		Map<String, Row> sed,
		RecordComparison cmp
	) {
		val buf = newDoubleArrayOfSize(RecordComparison::NUM_COMPARISONS)
		
		for (link: links) {
			val um = umetrics.get(link.employeeId)
			val s = sed.get(link.drfId)
			cmp.compare(um, s, buf, false)
			
			val result = RecordComparison::toStrings(buf)
			result.add(String.format("field-comparison-%d", label))
			file.printRow(result)
		}
		
		file.pr.flush
	}
	
	/**
	 * Create comparisons for a bootstrap sample of size n
	 */
	 def static writeComparisons(
		ModelInputFile file, 
		List<Link> links, 
		int label,
		Map<Integer, Row> umetrics, 
		Map<String, Row> sed,
		RecordComparison cmp,
		int n
	 ) {
	 	val sample = new LinkedList<Link>
	 	val rand = new Random
	 	
	 	for (i: 0 ..< n) {
	 		val j = rand.nextInt(links.size)
	 		val link = links.get(j)
	 		sample.add(link)
	 	}
	 	
	 	writeComparisons(file, sample, label, umetrics, sed, cmp)
	 }
	 
	 /**
	  * Create random comparisons not appearing in the list of links
	  */
	  def static writeRandomComparisons(
	  	ModelInputFile file,
	  	List<Link> links,
	  	int label,
	  	Map<Integer, Row> umetrics,
	  	Map<String, Row> sed,
	  	RecordComparison cmp,
	  	int n
	  ) {
	  	val sample = new LinkedList<Link>
	  	val rand = new Random
	  	
	  	val linkMap = new HashMap<Integer, String>
	  	
	  	for (link: links)
	  		linkMap.put(link.employeeId, link.drfId)
	  	
	  	val employeeIds = new ArrayList<Integer>(umetrics.keySet)
	  	val drfIds = new ArrayList<String>(sed.keySet)
	  	
	  	for (i: 0 ..< n) {
	  		var j = rand.nextInt(umetrics.size)
	  		var k = rand.nextInt(sed.size)
	  		
	  		var eid = employeeIds.get(j)
	  		var drfId = drfIds.get(k)
	  		
	  		while (linkMap.containsKey(eid) && linkMap.get(eid) == drfId) {
		  		j = rand.nextInt(umetrics.size)
		  		k = rand.nextInt(sed.size)
		  		
		  		eid = employeeIds.get(j)
		  		drfId = drfIds.get(k)
	  		}
	  		
	  		sample.add(new Link(eid, drfId))
	  	}
	  	
	  	writeComparisons(file, sample, label, umetrics, sed, cmp)
	  }
}