package rf

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.ArrayList
import java.util.Arrays
import java.util.HashMap
import java.util.List
import java.util.Map
import org.apache.lucene.search.spell.JaroWinklerDistance
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class RecordComparison {
	
	var public static NUM_COMPARISONS = 0
	val public static WORKED_AS_GRAD = NUM_COMPARISONS++
	
	val public static SRCEPRIM_ABDF = NUM_COMPARISONS++
	val public static SRCEPRIM_GHIJKL = NUM_COMPARISONS++
	val public static SRCEPRIM_MISSING = NUM_COMPARISONS++
	val public static SRCE_COUNT = NUM_COMPARISONS++
	
	val public static TUITREMS_EQ_4 = NUM_COMPARISONS++
	
	val public static PHDFIELD_SCI = NUM_COMPARISONS++
	val public static PHDFIELD_HLT = NUM_COMPARISONS++
	val public static PHDFIELD_SOC = NUM_COMPARISONS++
	
	val public static FIRST_NAME = NUM_COMPARISONS++
	val public static FIRST_NAME_FREQ_UMETRICS = NUM_COMPARISONS++
	val public static FIRST_NAME_FREQ_SED = NUM_COMPARISONS++
	
	val public static MIDDLE_JW = NUM_COMPARISONS++
	
	val public static LAST_NAME = NUM_COMPARISONS++
	val public static LAST_NAME_FREQ_UMETRICS = NUM_COMPARISONS++
	val public static LAST_NAME_FREQ_SED = NUM_COMPARISONS++
	
	val public static PHDCY_CMP_USTART = NUM_COMPARISONS++
	val public static PHDCY_EQ_MAX_GRAD_YEAR = NUM_COMPARISONS++
	val public static PHDCY_NEAR_MAX_GRAD_YEAR = NUM_COMPARISONS++
	
	val REPLACE_MISSING_VALUES = #[
		FIRST_NAME_FREQ_UMETRICS,
		FIRST_NAME_FREQ_SED,
		LAST_NAME_FREQ_UMETRICS,
		LAST_NAME_FREQ_SED,
		
		TUITREMS_EQ_4,
		
		MIDDLE_JW
	]
	
	def static toStrings(double[] arr) {
		new ArrayList(arr.map[if (!Double::isNaN(it)) String.format("%f", it) else "?"])
	}
	
	def static FieldNames() {
		val names = new ArrayList<String>(NUM_COMPARISONS)
		for (i: 0 ..< NUM_COMPARISONS)
			names.add("")
		
    	names.set(WORKED_AS_GRAD, "worked_as_grad_")
    	
    	names.set(SRCEPRIM_ABDF, "SRCEPRIM=ABDF")
    	names.set(SRCEPRIM_GHIJKL, "SRCEPRIM=GHIJKL")
    	names.set(SRCEPRIM_MISSING, "SRCEPRIM=Missing")
    	names.set(SRCE_COUNT, "SRCE_count")
    	
    	names.set(TUITREMS_EQ_4, "TUITREMS=4")
    	
    	names.set(PHDFIELD_SCI, "PHDFIELD=Science")
    	names.set(PHDFIELD_HLT, "PHDFIELD=Health")
    	names.set(PHDFIELD_SOC, "PHDFIELD=Sociology")

    	names.set(FIRST_NAME, "first_name_jw")
    	names.set(FIRST_NAME_FREQ_UMETRICS, "first_name_freq_umetrics")
    	names.set(FIRST_NAME_FREQ_SED, "first_name_freq_sed")
    	
    	names.set(MIDDLE_JW, "middle_jw")

    	names.set(LAST_NAME, "last_name_jw")
    	names.set(LAST_NAME_FREQ_UMETRICS, "last_name_freq_umetrics")
    	names.set(LAST_NAME_FREQ_SED, "last_name_freq_sed")
    	
    	names.set(PHDCY_CMP_USTART, "PHDCY~~Ustart")
    	names.set(PHDCY_EQ_MAX_GRAD_YEAR, "PHDCY=max_grad_year")
    	names.set(PHDCY_NEAR_MAX_GRAD_YEAR, "PHDCY~~max_grad_year")

        names
	}
	
	def void compare(Row um, Row sed, double[] result, boolean replaceMissing) {
		//println(um.getInteger("__employee_id"));
		//println("SED");
		//println(sed.getString("NAMFSTMI"));
		//println(sed);
		Arrays::fill(result, Double::NaN)
		
		val minPeriodStartDate = LocalDate::parse(um.getString("min_period_start_date"))
		val maxPeriodEndDate = LocalDate::parse(um.getString("max_period_end_date"))
		val umetricsYears = minPeriodStartDate.until(maxPeriodEndDate, ChronoUnit::MONTHS) / 12.0
		
		val firstAppearAsGradStr = um.getString("first_appear_as_grad_date")
		val lastAppearAsGradStr = um.getString("last_appear_as_grad_date")
		var double gradYears
		
		if (firstAppearAsGradStr == null || lastAppearAsGradStr == null) {
			gradYears = umetricsYears
		}
		else {
			val firstAppearAsGradDate = LocalDate::parse(firstAppearAsGradStr)
			val lastAppearAsGradDate = LocalDate::parse(lastAppearAsGradStr)
			gradYears = firstAppearAsGradDate.until(lastAppearAsGradDate, ChronoUnit::MONTHS) / 12.0
		}
		
		result.set(WORKED_AS_GRAD, if (um.getInteger("days_worked_as_grad") > 0) 1.0 else 0.0)
		//result.set(WORKED_AS_GRAD, um.getInteger("days_worked_as_grad")) 

		var s = sed.getString("SRCEPRIM")
		if (s != null) {
			result.set(SRCEPRIM_MISSING, 0.0)
			
			val test1 = (s == "A" || s == "B" || s == "D" || s == "F")
			result.set(SRCEPRIM_ABDF, if (test1) 1.0 else 0.0)
			
			val test2 = !test1 && (s == "G" || s == "H" || s == "I" || s == "J" || s == "K" || s == "L")
			result.set(SRCEPRIM_GHIJKL, if (test2) 1.0 else 0.0)
		}
		else {
			result.set(SRCEPRIM_MISSING, 1.0)
			result.set(SRCEPRIM_ABDF, 0.0)
			result.set(SRCEPRIM_GHIJKL, 0.0)
		}
		
		var srceCount = 0
		for (srcex: #["SRCEA", "SRCEB", "SRCEC", "SRCED", "SRCEE", "SRCEF"]) {
			if (1 == sed.getInteger(srcex))
			srceCount++
		}
		result.set(SRCE_COUNT, srceCount)
			
		var n = sed.getInteger("TUITREMS")
		if (n != null)
			result.set(TUITREMS_EQ_4, if (n.intValue == 4) 1.0 else 0.0)
			
		n = sed.getInteger("PHDFIELD")
		if (n != null) {
			val testScience = (0 <= n && n < 200) || (300 <= n && n < 600)
			val testHealth = (200 <= n && n < 300) || (650 <= n && n < 700)
			val testSociology = (600 <= n && n < 650)
			
			result.set(PHDFIELD_SCI, if (testScience) 1.0 else 0.0)
			result.set(PHDFIELD_HLT, if (testHealth) 1.0 else 0.0)
			result.set(PHDFIELD_SOC, if (testSociology) 1.0 else 0.0)
		}
		
		val words = sed.getString("NAMFSTMI").split("\\s+")
		val firstJw = jw.getDistance(um.getString("first_name"), words.get(0))
		val firstFullJw = jw.getDistance(um.getString("first_name"), sed.getString("NAMFSTMI"))
		result.set(FIRST_NAME, if (firstJw >= firstFullJw) firstJw else firstFullJw)
		
		s = um.getString("first_name")
		if (s != null && s.trim != "")
			result.set(FIRST_NAME_FREQ_UMETRICS, firstNameFrequency.get(um.getString("first_name")))
			
		s = words.get(0)
		if (s != null && s.trim != "")
			result.set(FIRST_NAME_FREQ_SED, firstNameFrequency.get(words.get(0)))
		
		if (words.length > 1) {
			val b = new StringBuilder(words.get(1))
			for (k: 2 ..< words.length)
				b.append(" ").append(words.get(k))
				
			val middleName = um.getString("middle_name") ?: ""
			result.set(MIDDLE_JW, jw.getDistance(middleName, b.toString))
		}
		

		result.set(LAST_NAME, jw.getDistance(um.getString("last_name"), sed.getString("NAMELAST")))
		
		s = um.getString("last_name")
		if (s != null && s.trim != "")
			result.set(LAST_NAME_FREQ_UMETRICS, lastNameFrequency.get(s))
			
		s = sed.getString("NAMELAST")
		if (s != null && s.trim != "")
			result.set(LAST_NAME_FREQ_SED, lastNameFrequency.get(s))
		
		val phdcy = sed.getInteger("PHDCY").intValue
		n = um.getInteger("max_grad_year")
		
		if (n != null) {
			val maxGradYear = n.intValue
			val phdcyEqMaxGradYear = phdcy == maxGradYear
			result.set(PHDCY_EQ_MAX_GRAD_YEAR, if (phdcyEqMaxGradYear) 1.0 else 0.0)
			
			val diff = phdcy - maxGradYear
			result.set(PHDCY_NEAR_MAX_GRAD_YEAR, if (!phdcyEqMaxGradYear && -1 <= diff && diff <= 2) 1.0 else 0.0)
			
		}
			
		val minYear = um.getInteger("min_year")
		result.set(PHDCY_CMP_USTART,
			if (phdcy > minYear)
				1.0
			else if (phdcy == minYear || phdcy == minYear - 1)
				2.0
			else
				3.0
			)
			
		if (replaceMissing) {
			for (ix: REPLACE_MISSING_VALUES) {
				if (Double::isNaN(result.get(ix))) {
					val m = means.get(fieldNames.get(ix))
					result.set(ix, m)
				}
			}
		}
	}
	
	new(Map<String, Double> means, Map<String, Double> firstNameFrequency, Map<String, Double> lastNameFrequency) {
		jw = new JaroWinklerDistance
		this.means = means
		this.firstNameFrequency = firstNameFrequency
		this.lastNameFrequency = lastNameFrequency
		fieldNames = FieldNames
	}
	
	new(Map<String, Double> firstNameFrequency, Map<String, Double> lastNameFrequency) {
		this(new HashMap<String, Double>, firstNameFrequency, lastNameFrequency)
	}
	
	val JaroWinklerDistance jw
	val Map<String, Double> means
	val Map<String, Double> firstNameFrequency
	val Map<String, Double> lastNameFrequency
	val List<String> fieldNames
}
