package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

interface ObservationContainerHandle {

	void addComponent(final String[] component);
	ObservationSchema getSchema();
}
