package rf

import java.util.LinkedList
import java.util.TreeMap

class Row
implements Iterable<String> 
{
	public enum Type { STRING, INTEGER, DOUBLE }

	val columnNames = new LinkedList<String>
	val columnTypes = new TreeMap<String, Type>
	val smap = new TreeMap<String, String> 
	val imap = new TreeMap<String, Integer> 
	val dmap = new TreeMap<String, Double>
	
	def addString(String name, String value) {
		columnNames.add(name)
		columnTypes.put(name, Type.STRING)
		smap.put(name, value)
		
		this
	}
	
	def addInteger(String name, Integer value) {
		columnNames.add(name)
		columnTypes.put(name, Type.INTEGER)
		imap.put(name, value)
		
		this
	}
	
	def addDouble(String name, Double value) {
		columnNames.add(name)
		columnTypes.put(name, Type.DOUBLE)
		dmap.put(name, value)
		
		this
	}
	
	def parseAdd(String name, String value, Type type) {
		switch type {
			case INTEGER: 
				if (value.empty)
					addInteger(name, null)
				else
					addInteger(name, Integer.parseInt(value))
					
			case DOUBLE:
				if (value.empty)
					addDouble(name, null)
				else
					addDouble(name, Double.parseDouble(value))
					
			default: addString(name, value)
		}
	}
	
	def getString(String name) { smap.get(name) }
	def getInteger(String name) { imap.get(name) }
	def getDouble(String name) { dmap.get(name) }
	
	def setString(String name, String value) {
		if (!smap.containsKey(name))
			throw new IllegalArgumentException(String.format("No string field: '%s'", name))
			
		smap.put(name, value)
	}
	
	def setInteger(String name, Integer value) {
		if (!imap.containsKey(name))
			throw new IllegalArgumentException(String.format("No integer field: '%s'", name))
			
		imap.put(name, value)
	}
	
	def setDouble(String name, Double value) {
		if (!dmap.containsKey(name))
			throw new IllegalArgumentException(String.format("No double field: '%s'", name))
			
		dmap.put(name, value)
	}
	
	def contains(String name, Type type) {
		switch type {
			case INTEGER: imap.containsKey(name)
			case DOUBLE: dmap.containsKey(name)
			default: smap.containsKey(name)
		}
	}
	
	def private columnString(String columnName) {
		switch columnTypes.get(columnName) {
			case INTEGER: {
				val ivalue = imap.get(columnName)
				if (ivalue != null) String.format("%d", ivalue) else "?"
			}
			case DOUBLE: {
				val dvalue = dmap.get(columnName)
				if (dvalue != null) String.format("%.4f", dvalue) else "?"
			}
			default:
				smap.get(columnName) ?: "?"
		}
	}
	
	override iterator() {
		val list = columnNames.map[columnString(it)].toList
		list.iterator
	}
	
	def addFields(Row row) {
		for (name: row.columnNames) {
			switch row.columnTypes.get(name) {
				case STRING: addString(name, row.getString(name))
				case INTEGER: addInteger(name, row.getInteger(name))
				case DOUBLE: addDouble(name, row.getDouble(name))
			}
		}
	}
	
}