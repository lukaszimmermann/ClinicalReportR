package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.List;

/**
 * An ObservationContainer bundles observations logically together.
 * 
 * @author lukaszimmermann
 */
public interface ObservationContainer {
	
	ObservationSchema getSchema();

	ObservationBuilder constructNewObservation();
	
	int numObservations();
	
	List<String[]> getRawObservations();
}
