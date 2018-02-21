package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

/**
 * An ObservationContainer bundles observations logically together.
 * 
 * @author lukaszimmermann
 */
public interface ObservationContainer {
	
	ObservationSchema getSchema();

	ObservationBuilder constructNewObservation();
}
