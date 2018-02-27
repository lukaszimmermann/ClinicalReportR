package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.Set;

public interface Observation {
	
	String getAttribute(final String key);
	Set<String> getKeys();
	boolean hasKey(final String key);
}
