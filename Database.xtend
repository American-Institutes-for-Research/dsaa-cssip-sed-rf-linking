package rf

import java.sql.Connection
import java.sql.DriverManager
import java.sql.ResultSet
import java.util.Collection
import java.util.HashMap
import java.util.Map
import rf.Row.Type

import static rf.Row.Type.*

class Database {
	
	val public static sedFields = newLinkedHashMap(
		"DRF_ID" -> STRING,
		"PHDINST" -> STRING,
		"NAMFSTMI" -> STRING,
		"NAMELAST" -> STRING,
		"PHDCY" -> INTEGER,
		"PHDFY" -> INTEGER,
		"YRSCOURS" -> INTEGER,
		"YRSDISST" -> INTEGER,
		"SRCEPRIM" -> STRING,
		"SRCESEC" -> STRING,
		"SRCEA" -> INTEGER,
		"SRCEB" -> INTEGER,
		"SRCEC" -> INTEGER,
		"SRCED" -> INTEGER,
		"SRCEE" -> INTEGER,
		"SRCEF" -> INTEGER,
		"TUITREMS" -> INTEGER,
		"PHDFIELD" -> INTEGER
	)
	
	val public static umetricsFields = newLinkedHashMap(
		"__employee_id" -> INTEGER,
		"university" -> STRING,
		"days_worked" -> INTEGER,
		"days_worked_as_grad" -> INTEGER,
		"first_name" -> STRING,
		"middle_name" -> STRING,
		"last_name" -> STRING,
		"dob_yr" -> INTEGER,
		"dob_mo" -> INTEGER,
		"max_year" -> INTEGER,
		"min_year" -> INTEGER,
		"max_grad_year" -> INTEGER,
		"min_period_start_date" -> STRING,
		"max_period_end_date" -> STRING,
		"first_appear_as_grad_date" -> STRING,
		"last_appear_as_grad_date" -> STRING
	)
	
	
	new(String host, String user, String pass) {
		Class::forName("com.mysql.jdbc.Driver")
		
		val url = String.format("jdbc:mysql://%s", host)
		conn = DriverManager::getConnection(url, user, pass)
	}
	
	def getUmetrics(Collection<String> universities) {
		
		val universityList = stringList(universities)
		
		val sql = "select __employee_id, university, days_worked, days_worked_as_grad,
			first_name,middle_name, last_name,
			case when max_grad_year is null or max_grad_year = 0 
				then year(max_period_end_date) 
				else max_grad_year end max_grad_year, 
			year(max_period_end_date) max_year, year(min_period_start_date) min_year,
			min_period_start_date, max_period_end_date,
			first_appear_as_grad_date, last_appear_as_grad_date,
		 	month(dob) dob_mo, year(dob) dob_yr
			from air.sm_input_sed_11242015 where university in (%s)"	
		val result = new HashMap<Integer, Row>
		
		val stmt = conn.createStatement
		val rs = stmt.executeQuery(String.format(sql, universityList))
		
		while (rs.next) {
			val row = newRow(umetricsFields, rs)
			result.put(row.getInteger("__employee_id"), row)
		}
		
		result
	}
	
	def getUmetrics(String university) {
		getUmetrics(#[university])
	}
	
	def getSed(Collection<String> phdinsts) {
		val institutions = stringList(phdinsts)
		
		val sql =
			"select sed.DRF_ID, sed.PHDINST, sed.NAMELAST, sed.NAMFSTMI, sed.PHDCY, sed.PHDFY,
 			sed.BIRTHMO, sed.BIRTHYR, sed.YEARSFT, sed.YRSCOURS, sed.YRSDISST, sed.YRSGRAD, 
			sed.SRCEPRIM, sed.SRCESEC, sed.TUITREMS, sed.PHDFIELD,
			sed.SRCEA, sed.SRCEB, sed.SRCEC, sed.SRCED, sed.SRCEE, sed.SRCEF
			from seddata.sed
			where PHDINST in (%s)"
			
		val result = new HashMap<String, Row>
		
		val stmt = conn.createStatement
		val rs = stmt.executeQuery(String.format(sql, institutions))
		
		while (rs.next) {
			val row = newRow(sedFields, rs)
			result.put(row.getString("DRF_ID"), row)
		} 
		
		result
	}
	
	def getSed(String phdinst) {
		getSed(#[phdinst])
	}
	
	private def static stringList(Collection<String> list) {
		String.join(", ", list.map[String.format("'%s'", it)])
	}
	
	private def static newRow(Map<String, Type> fields, ResultSet rs) {
		val row = new Row
		
		for (entry: fields.entrySet) {
			val name = entry.key
			
			switch entry.value {
				case INTEGER: row.addInteger(name, rs.getInt(name))
				case DOUBLE: row.addDouble(name, rs.getDouble(name))
				case STRING: row.addString(name, rs.getString(name))
			}
		}
		
		row
	}
	
	val Connection conn
}