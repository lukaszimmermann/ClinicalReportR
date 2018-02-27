package de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationBuilder;

public enum MissingValuesNA implements MissingValuesStrategy {

	INSTANCE;

	@Override
	public String resolve(final ObservationBuilder b) {
		
		return "NA";
	}	
}
