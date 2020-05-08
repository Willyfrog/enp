<xsl:stylesheet version="1.0" 
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:wi="http://schemas.microsoft.com/wix/2006/wi">

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  
  <!-- src.: https://stackoverflow.com/a/19259647/3514658 -->
  <xsl:template match="wi:ComponentGroup[@Id='EnpDesktopFiles']/wi:Component/wi:File[contains(@Source,'desktop_poc.exe')]">
     <xsl:copy>
        <xsl:attribute name="Id">EnpDesktopEXE</xsl:attribute>
        <xsl:copy-of select="@*[name()!='Id']"/>
        <xsl:apply-templates />
     </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

