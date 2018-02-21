package de.ekut.wsi.abi.clinicalreporting.generator.model.document;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.json.JSONArray;
import org.json.JSONObject;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.DefaultObservationContainer;
import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationSchema;
import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationUtils;
import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues.MissingValuesNA;

public final class DocumentTree implements DocumentTreeNode {


	private static final List<String> keyOrder = Arrays.asList(
			"Somatic Mutations in Known Driver Genes",
			"Somatic Mutations in Pharmaceutical Target Proteins",
			"Somatic Mutations with known pharmacogenetic effect",
			"Appendix",
			"Gene",
			"Mutation",
			"Therapy",
			"Disease",
			"Evidence",
			"Confidence",
			"References");
	
	
	/** 
	 * Orders the Strings in the keySet according to the ordering defined in the keyOrder field
	 * @param keySet
	 * @return
	 */
	private static List<String> order(final Set<String> keySet) {
		
		final List<String> result = new ArrayList<>(keySet.size());
		for (final String key : DocumentTree.keyOrder) {
			
			if (keySet.contains(key) && ! result.contains(key)) {
				
				result.add(key);
			}	
		}
		// Add all the remaining keys from the keySet to the result
		for (final String key : keySet) {
			
			if ( ! result.contains(key)) {
				
				result.add(key);
			}
		}
		return result;
	}
	
	
	/**
	 * Tests whether the values of the JSONObject only consists of literals
	 * @param o
	 * @return
	 */
	private static final boolean isLeaf(final JSONObject o) {
		
		final Iterator<String> oIterator = o.keys();
		while (oIterator.hasNext()) {
			
			final Object thing = o.get(oIterator.next());
			if (thing instanceof JSONObject) {
				
				return false;
			}
		}
		return true;
	}
	
	
	
	private static final DocumentTable getTable(
			final JSONArray array,
			final String key) {
		
		final Set<String> objects = new HashSet<>();
		final Iterator<Object> arrayContentIterator = array.iterator();
		
		// Keeps track of all the key-value pairs of the observations encountered
		final List<Map<String, String>> plainObservations = new ArrayList<>();
		
		while (arrayContentIterator.hasNext()) {
			
			final Object nextObject = arrayContentIterator.next();
			
			// All of the Elements in the table must be Objects
			if ( ! (nextObject instanceof JSONObject)) {
				return null;
			}
			final JSONObject jsonObject = (JSONObject) nextObject;
			
			// ensure that all children of the jsonObject are literals
			if ( ! DocumentTree.isLeaf(jsonObject)) {
				return null;
			}
			final Set<String> keys = jsonObject.keySet();
			
			// fetch all key-value pairs
			final Map<String, String> observation = new HashMap<>(keys.size());
			for (final String nextKey : keys) {
				observation.put(nextKey, jsonObject.get(nextKey).toString());
			}
			plainObservations.add(observation);
			objects.addAll(jsonObject.keySet());
		}
		
		// Construct all the observations based on the schema
		final DefaultObservationContainer container = new DefaultObservationContainer(
				new ObservationSchema(DocumentTree.order(objects)));
	
		// Construct a new observation in the container for each of the plain observations
		for (final Map<String, String> plainObservation : plainObservations) {
			
			ObservationUtils.addPlainObservation(container, plainObservation, MissingValuesNA.INSTANCE);
		}

		return new DocumentTable(container, key);
	}
	
	
	
	private final List<DocumentTreeNode> children;
	private final String label;
	
	private DocumentTree(final String label) {
		
		this.children = new ArrayList<>();
		this.label = label;
	}
	
	private void addChild(final DocumentTreeNode documentTreeNode) {
		
		this.children.add(documentTreeNode);
	}
	
	/** Parses an object into a document tree node. 
	 * 
	 */
	public static DocumentTreeNode parse(final Object o) {
		
		return DocumentTree.parse(o, null);
	}
	
	private static DocumentTreeNode parse(final Object o, final String key) {
		
		if (o instanceof JSONObject) {
						
			// Each object in the JSON tree corresponds to another DocumentTree
			final DocumentTree result = new DocumentTree(key);
			final JSONObject jsonObject = (JSONObject) o;
			final List<String> jsonObjectKeys = DocumentTree.order(jsonObject.keySet());
			
			// Construct a DocumentTreeNode for each of the keys of this JSON object
			// and push to the list of children
			for (final String nextKey : jsonObjectKeys) {
				
				result.addChild(DocumentTree.parse(jsonObject.get(nextKey), nextKey));
			}
			
			return result;
			
		} else if (o instanceof JSONArray) {
			
			final JSONArray jsonArray = (JSONArray) o;
			// We have to check if this JSON Array corresonds to a table
			final DocumentTable table = DocumentTree.getTable(jsonArray, key);
			
			if (table == null) {
				
				throw new IllegalStateException("Array must be table, otherwise cannot parse");
			}
			return table;
		}
		throw new IllegalStateException("Invalid Type of node");
	}


	@Override
	public int getHeight() {
		
		return this.children.stream().mapToInt(x -> x.getHeight()).max().orElse(0) + 1;
	}

	@Override
	public String getLabel() {
		
		return this.label;
	}


	@Override
	public List<DocumentTreeNode> getChildren() {
		
		return this.children;
	}
}
