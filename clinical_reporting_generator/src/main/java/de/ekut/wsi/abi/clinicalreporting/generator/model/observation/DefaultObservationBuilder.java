package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues.MissingValuesStrategy;

final class DefaultObservationBuilder implements ObservationBuilder {

	private final ObservationContainerHandle observationContainerHandle;
	private final String[] keys;
	private final String[] values;
	private final int size;
	private int index;

	DefaultObservationBuilder(
			final ObservationContainerHandle handle) {

		this.observationContainerHandle = handle;
		this.keys = handle.getSchema().getKeys();
		this.size = this.keys.length;
		this.values = new String[this.size];
		this.index = 0;
	}

	private void checkExhausted() {
		
		if ( ! this.hasMoreAttributes()) {
			
			// TODO Message
			throw new IllegalStateException();
		}
	}

	@Override
	public String getKey() throws IllegalStateException {
		
		this.checkExhausted();
		return this.keys[this.index];
	}


	@Override
	public ObservationBuilder withNextAttribute(final String value) {
		
		this.checkExhausted();
		this.values[this.index++] = value;
		return this;
	}


	@Override
	public Observation build(final MissingValuesStrategy missingValuesStrategy) {
	
		// fill the remaining values with the missing values strategy
		for (int i = this.index; i < this.size; ++i) {
			
			this.values[i] = missingValuesStrategy.resolve(this);
		}
		
		this.observationContainerHandle.addComponent(Arrays.copyOf(this.values, this.values.length));
		final Map<String, String> plainObservation = new HashMap<>();
	
		// Map keys and values
		for (int i = 0; i < this.keys.length; ++i) {
			
			plainObservation.put(this.keys[i], this.values[i]);
		}
		return new DefaultObservation(plainObservation);
	}

	@Override
	public boolean hasMoreAttributes() {
		
		return this.index < this.size;
	}
}