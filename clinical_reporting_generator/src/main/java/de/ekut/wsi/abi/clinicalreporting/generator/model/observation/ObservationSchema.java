package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.Arrays;
import java.util.List;

/**
 * An Observation schema consists of a list of attributes (Strings) that an observation has.
 * 
 * @author lukaszimmermann
 *
 */
public final class ObservationSchema {

	private final String[] keys;

	/**
	 * Creates a new Observation Schema based on the ordered sequence of keys provided
	 * 
	 * @param keys
	 */
	public ObservationSchema(final String[] keys) {

		// Copy makes ObservationSchema immutable
		this.keys = Arrays.copyOf(keys, keys.length);
	}
	
	public ObservationSchema(final List<String> keys) {
		
		this.keys = keys.toArray(new String[] {});
	}
	
	public String[] getKeys() {
		
		return Arrays.copyOf(this.keys, this.keys.length);
	}
}
