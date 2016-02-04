package rf

import java.io.BufferedWriter
import java.io.PrintWriter
import java.nio.file.Files
import java.nio.file.Path
import java.util.LinkedList
import java.util.List
import org.apache.commons.csv.CSVFormat
import org.apache.commons.csv.CSVPrinter
import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class ModelInputFile {
	
	val public static RELATION = "field-comparison"
	val public static MAX_LEVEL = 4
	
	val static LABEL_TYPE = "{" + String.join(",", (0..MAX_LEVEL).map[String.format("%s-%d", RELATION, it)]) + "}"
	
	new(Path path, List<String> comparisonFields) {
		relation = RELATION
		this.comparisonFields = new LinkedList<String>(comparisonFields)
		
		out = Files.newBufferedWriter(path)
		pr = CSVFormat::EXCEL.print(out)
	}
	
	def printHeader() {
		val wr = new PrintWriter(out)
		
		wr.format("@RELATION %s\r\n\r\n", relation)
		
		for (field: comparisonFields) {
			wr.format("@ATTRIBUTE %s NUMERIC\r\n", field)
		}
		
		wr.format("@ATTRIBUTE label %s", LABEL_TYPE)
		
		wr.format("\r\n@DATA\r\n")
		wr.flush
	}
	
	def printRow(Iterable<String> row) {
		pr.printRecord(row)
	}
	
	def close() {
		pr.flush
		pr.close
	}
	
	val String relation
	val List<String> comparisonFields
	val BufferedWriter out
	val CSVPrinter pr
}