package de.ekut.wsi.abi.clinicalreporting.generator.model.observation;

import java.util.Map;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.missingvalues.MissingValuesStrategy;

public final class ObservationUtils {

	private ObservationUtils() {
		
		throw new AssertionError();
	}
	
	public static Observation addPlainObservation(
			final ObservationContainer observationContainer,
			final Map<String, String> plainObservation,
			final MissingValuesStrategy missingValueStrategy) {
		
		ObservationBuilder builder = observationContainer.constructNewObservation();		
		while (builder.hasMoreAttributes()) {
		
			final String nextKey = builder.getKey();
			
			// If the plainObservation does not contain the requested key, use missing value strategy to
			// supplement
			if ( plainObservation.containsKey(nextKey)) {
				
				builder = builder.withNextAttribute(plainObservation.get(nextKey));
				
			} else {
				
				builder = builder.withNextAttribute(missingValueStrategy.resolve(builder));
			}
		}
		return builder.build(missingValueStrategy);
	}
}
