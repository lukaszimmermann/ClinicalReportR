package de.ekut.wsi.abi.clinicalreporting.generator.model.document;

import java.util.List;

public interface DocumentTreeNode {

	int getHeight();
	String getLabel();
	
	List<DocumentTreeNode> getChildren();
}
