package de.ekut.wsi.abi.clinicalreporting.generator.model;

import java.util.ArrayList;
import java.util.List;

import de.ekut.wsi.abi.clinicalreporting.generator.model.contentblocks.ContentBlock;

public final class ClinicalReport {

	// We represent a clinical report as a sequence of ContentBlocks
	private final List<ContentBlock> blocks;
	
	public ClinicalReport(final List<ContentBlock> blocks) {
		
		this.blocks = new ArrayList<>(blocks);
	}
}
