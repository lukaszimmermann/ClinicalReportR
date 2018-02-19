package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class DefaultObservation implements Observation {

	private final Map<String, String> attributes;
	
	DefaultObservation(final Map<String, String> attributes) {
		
		this.attributes = new HashMap<>(attributes);
	}
	
	@Override
	public String getAttribute(final String key) {
		
		return this.attributes.get(key);
	}
	
	public int getSize() {
		
		return this.attributes.size();
	}

	@Override
	public Set<String> getKeys() {
		
		return new HashSet<>(this.attributes.keySet());
	}

	@Override
	public boolean hasKey(final String key) {
		
		return this.attributes.containsKey(key);
	}
}
