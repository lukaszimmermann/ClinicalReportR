package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues.MissingValuesStrategy;

public interface ObservationBuilder {

	/**
	 * Gets the key that the ObservationKeySetter is expecting next
	 * @return
	 */
	String getKey() throws IllegalStateException;
	ObservationBuilder withNextAttribute(final String value);
	Observation build(final MissingValuesStrategy missingValuesStrategy);
	boolean hasMoreAttributes();
}
