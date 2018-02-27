package de.ekut.wsi.abi.clinicalreporting.generator.model.docx4j;

import org.docx4j.wml.JcEnumeration;
import org.docx4j.wml.STVerticalJc;

public final class DocxStyle {

	private final boolean bold;
	private final boolean italic;
	private final boolean underline;
	private final String fontSize;
	private final String fontColor; 
	private final String fontFamily;

	// cell margins
	private final int left;
	private final int bottom;
	private final int top;
	private final int right;

	private final String background;
	private final STVerticalJc verticalAlignment;
	private final JcEnumeration horizAlignment;

	private final boolean borderLeft;
	private final boolean borderRight;
	private final boolean borderTop;
	private final boolean borderBottom;
	private final boolean noWrap;

	public static class Builder {

		private boolean bold;
		private boolean italic;
		private boolean underline;
		private String fontSize;
		private String fontColor; 
		private String fontFamily;

		// cell margins
		private int left;
		private int bottom;
		private int top;
		private int right;

		private String background;
		private STVerticalJc verticalAlignment;
		private JcEnumeration horizAlignment;

		private boolean borderLeft;
		private boolean borderRight;
		private boolean borderTop;
		private boolean borderBottom;
		private boolean noWrap;


		public Builder bold(final boolean val) {

			this.bold = val;
			return this; 
		}
		public Builder italic(final boolean val) {

			this.italic = val;
			return this; 
		}
		public Builder underline(final boolean val) {

			this.underline = val;
			return this; 
		}
		public Builder fontSize(final String val) {

			this.fontSize = val;
			return this; 
		}
		public Builder fontColor(final String val) {

			this.fontColor = val;
			return this; 
		}
		public Builder fontFamily(final String val) {

			this.fontFamily = val;
			return this; 
		}

		public Builder leftMargin(final int val) {

			this.left = val;
			return this; 
		}
		public Builder bottomMargin(final int val) {

			this.bottom = val;
			return this; 
		}
		public Builder rightMargin(final int val) {

			this.right = val;
			return this; 
		}
		public Builder topMargin(final int val) {

			this.top = val;
			return this; 
		}

		public Builder background(final String val) {

			this.background = val;
			return this; 
		}

		public Builder verticalAlignment(final STVerticalJc val) {

			this.verticalAlignment = val;
			return this; 
		}
		public Builder horizAlignment(final JcEnumeration val) {

			this.horizAlignment = val;
			return this; 
		}

		public Builder borderLeft(final boolean val) {

			this.borderLeft = val;
			return this; 
		}
		public Builder borderRight(final boolean val) {

			this.borderRight = val;
			return this; 
		}

		public Builder borderTop(final boolean val) {

			this.borderTop = val;
			return this; 
		}

		public Builder borderBottom(final boolean val) {

			this.borderBottom = val;
			return this; 
		}

		public Builder noWrap(final boolean val) {

			this.noWrap = val;
			return this; 
		}

		public DocxStyle build()  {

			return new DocxStyle(this);
		}	
	}

	private DocxStyle(final Builder builder) {

		this.bold = builder.bold;
		this.italic = builder.italic;
		this.underline = builder.underline;
		this.fontSize = builder.fontSize;
		this.fontColor = builder.fontColor;
		this.fontFamily = builder.fontFamily;

		// cell margins
		this.left = builder.left;
		this.bottom = builder.bottom;
		this.top = builder.top;
		this.right = builder.right;

		this.background = builder.background;
		this.verticalAlignment = builder.verticalAlignment;
		this.horizAlignment = builder.horizAlignment;

		this.borderLeft = builder.borderLeft;
		this.borderRight = builder.borderRight;
		this.borderTop = builder.borderTop;
		this.borderBottom = builder.borderBottom;
		this.noWrap = builder.noWrap;
	}

	public boolean isBold() {
		return this.bold;
	}

	public boolean isItalic() {
		return this.italic;
	}

	public boolean isUnderline() {
		return this.underline;
	}

	public String getFontSize() {
		return this.fontSize;
	}

	public String getFontColor() {
		return this.fontColor;
	}

	public String getFontFamily() {
		return this.fontFamily;
	}

	public int getLeft() {
		return this.left;
	}

	public int getBottom() {
		return this.bottom;
	}

	public int getTop() {
		return this.top;
	}

	public int getRight() {
		return this.right;
	}

	public String getBackground() {
		return this.background;
	}

	public STVerticalJc getVerticalAlignment() {
		return this.verticalAlignment;
	}

	public JcEnumeration getHorizAlignment() {
		return this.horizAlignment;
	}

	public boolean isBorderLeft() {
		return this.borderLeft;
	}

	public boolean isBorderRight() {
		return this.borderRight;
	}

	public boolean isBorderTop() {
		return this.borderTop;
	}

	public boolean isBorderBottom() {
		return this.borderBottom;
	}

	public boolean isNoWrap() {
		return this.noWrap;
	}
}