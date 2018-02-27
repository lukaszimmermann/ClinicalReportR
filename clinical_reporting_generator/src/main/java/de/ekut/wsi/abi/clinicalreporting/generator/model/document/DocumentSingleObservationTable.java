package de.ekut.wsi.abi.clinicalreporting.generator.model.document;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.Observation;

public final class DocumentSingleObservationTable implements DocumentTreeNode {

	private final Observation observation;
	private final String title;

	public DocumentSingleObservationTable(
			final Observation observation,
			final String title) {

		this.observation = Objects.requireNonNull(observation);
		this.title = Objects.requireNonNull(title);
	}

	@Override
	public int getHeight() {

		return 0;
	}

	@Override
	public String getLabel() {

		return this.title;
	}

	@Override
	public List<DocumentTreeNode> getChildren() {

		return new ArrayList<>();
	}
	
	public Observation getObservation() {
		
		return this.observation;
	}
	
	public String getTitle() {
		
		return this.title;
	}
}
