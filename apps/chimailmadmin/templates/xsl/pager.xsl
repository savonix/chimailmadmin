<!--
Program: ChiMailMadmin.com
Component: pager.xsl
Copyright: Savonix Corporation
Author: Albert L. Lash, IV
License: Gnu Affero Public License version 3
http://www.gnu.org/licenses

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program; if not, see http://www.gnu.org/licenses
or write to the Free Software Foundation, Inc., 51 Franklin Street,
Fifth Floor, Boston, MA 02110-1301 USA
-->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns="http://www.w3.org/1999/xhtml">
<!-- This template is used by pages which use the tablesorter and the table paginator -->
	<xsl:template name="jquery-setup">
		<xsl:param name="my-table"/>
		<xsl:param name="my-table-div"/>
		<xsl:param name="my-sort-column"/>
		<xsl:param name="no-sort-column"/>
		<xsl:param name="my-page-num">0</xsl:param>
		<script type="text/javascript">
		$(document).ready(function()
				{
						rotate_controls();
						$("#<xsl:value-of select="$my-table"/>")
						.tablesorter(
								{
										widgets:['zebra','cookie']
										<xsl:value-of select="$my-sort-column"/>
										<xsl:value-of select="$no-sort-column"/>
								}
						)
						.tablesorterPager(
								{
										container: $("#<xsl:value-of select="$my-table"/>-pager"),
										size: 16,
                    positionFixed: false
								}
						);
				}
		);
		</script>
		</xsl:template>

	<!-- This template is used by pages which only use the tablesorter,
		not the paginator-->
	<xsl:template name="jquery-setup-simple">
		<xsl:param name="my-table"/>
		<xsl:param name="my-sort-column"/>
		<xsl:param name="no-sort-column"/>
		<script type="text/javascript">
		$(document).ready(function()
				{
						$("#<xsl:value-of select="$my-table"/>")
						.tablesorter(
								{
										widgets:['zebra','cookie'],
										<xsl:value-of select="$my-sort-column"/>
										<xsl:value-of select="$no-sort-column"/>
								}
						);
				}
		);
		</script>
	</xsl:template>

	<xsl:template name="pager">
    <xsl:param name="path_prefix">
			<xsl:value-of select="/_R_/runtime/path_prefix"/>
		</xsl:param>
		<xsl:param name="my-table"/>

		<div id="{$my-table}-pager" class="pager">
			<input id="mypagesize" class="pagesize" type="hidden" name="pagesize" value="16"/>
			<table>
				<tr>
					<td>
						<img id="ts_first" class="first pointer" alt="&lt;&lt;"/>
						<img id="ts_prev" class="prev pointer" alt="&lt;"/>
					</td>
					<td>
						<input type="text" class="pagedisplay" size="4" readonly="readonly"/>
					</td>
					<td>
						<img id="ts_next" class="next pointer" alt="&gt;"/>
						<img id="ts_last" class="last pointer" alt="&gt;&gt;"/>
					</td>
				</tr>
			</table>
		</div>
	</xsl:template>
</xsl:stylesheet>
