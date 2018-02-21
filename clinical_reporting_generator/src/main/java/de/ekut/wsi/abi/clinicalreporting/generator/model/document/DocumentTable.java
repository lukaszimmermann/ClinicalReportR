package de.ekut.wsi.abi.clinicalreporting.generator.model.document;

import java.util.ArrayList;
import java.util.List;

import de.ekut.wsi.abi.clinicalreporting.generator.model.observation.ObservationContainer;

/**
 * Represents a table in the document as specified in the JSON file
 * @author zimmerl
 *
 */

public final class DocumentTable implements DocumentTreeNode {

	private final ObservationContainer container;
	private final String title;
	
	public DocumentTable(final ObservationContainer observationContainer, final String title) {
		
		this.container = observationContainer;
		this.title = title;
	}
	
	public ObservationContainer getObservationContainer() {
		
		return this.container;
	}
	
	public String getTitle() {
		
		return this.title;
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
}
