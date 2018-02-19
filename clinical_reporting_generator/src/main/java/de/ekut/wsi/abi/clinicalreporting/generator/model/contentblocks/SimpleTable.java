package de.ekut.wsi.abi.clinicalreporting.generator.model.contentblocks;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationContainer;

public class SimpleTable implements ContentBlock, Table {

	private final String title;
	private final ObservationContainer observations;
	
	public SimpleTable(final String title, final ObservationContainer observationContainer) {
		
		this.title = title;
		this.observations = observationContainer;
	}
	
	@Override
	public String getTitle() {
		
		return this.title;
	}
	
	public ObservationContainer getObservationContainer() {
		
		return this.observations;
	}
}
