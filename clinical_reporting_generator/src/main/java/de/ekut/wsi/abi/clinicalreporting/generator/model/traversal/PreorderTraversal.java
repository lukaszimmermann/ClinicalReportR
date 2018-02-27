package de.ekut.wsi.abi.clinicalreporting.generator.model.traversal;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.NoSuchElementException;

import de.ekut.wsi.abi.clinicalreporting.generator.model.document.DocumentTreeNode;

public final class PreorderTraversal implements DocumentTreeTraversal {

	private final DocumentTreeNode documentTreeNode;

	public PreorderTraversal(final DocumentTreeNode documentTreeNode) {

		this.documentTreeNode = documentTreeNode;
	}

	@Override
	public Iterator<DocumentTreeNode> iterator() {

		final List<Iterator<DocumentTreeNode>> childIterators = new ArrayList<>();
		for (DocumentTreeNode treeNode : PreorderTraversal.this.documentTreeNode.getChildren()) {
			childIterators.add(new PreorderTraversal(treeNode).iterator());
		}
		return new Iterator<DocumentTreeNode>() {

			private int index = 0;
			private boolean root = true;

			@Override
			public boolean hasNext() {

				return root || (index < childIterators.size() - 1) || (index < childIterators.size() && childIterators.get(index).hasNext()); 
			}

			@Override
			public DocumentTreeNode next() {

				if (root) {
					root = false;
					return PreorderTraversal.this.documentTreeNode;
				}
				
				final Iterator<DocumentTreeNode> currentIterator = childIterators.get(index);
				if (currentIterator.hasNext()) {
					return currentIterator.next();
				}
				index++;

				if (index == childIterators.size()) {

					throw new NoSuchElementException();
				}
				return childIterators.get(index).next();
			}
		};
	}
}
