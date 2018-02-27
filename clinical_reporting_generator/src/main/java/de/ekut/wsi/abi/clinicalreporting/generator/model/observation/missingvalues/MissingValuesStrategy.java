package de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationBuilder;

public interface MissingValuesStrategy {

	String resolve(final ObservationBuilder b);
}
