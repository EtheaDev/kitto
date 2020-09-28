Ext.LinkButton = Ext.extend(Ext.Button, {
    template: new Ext.Template(
        '<table cellspacing="0" class="x-btn {3}"><tbody class="{4}">',
        '<tr><td class="x-btn-tl"><i>&amp;#160;</i></td><td class="x-btn-tc"></td><td class="x-btn-tr"><i>&amp;#160;</i></td></tr>',
        '<tr><td class="x-btn-ml"><i>&amp;#160;</i></td><td class="x-btn-mc"><em class="{5}" unselectable="on"><a href="{6}" target="{7}"><div class="x-btn-text {2}"><button>{0}</button></div></a></em></td><td class="x-btn-mr"><i>&amp;#160;</i></td></tr>',
        '<tr><td class="x-btn-bl"><i>&amp;#160;</i></td><td class="x-btn-bc"></td><td class="x-btn-br"><i>&amp;#160;</i></td></tr>',
        '</tbody></table>').compile(),

    buttonSelector : 'div:first',

    getTemplateArgs: function() {
        return Ext.Button.prototype.getTemplateArgs.apply(this).concat([this.href, this.target]);
    },

    onClick : function(e){
        if(e.button != 0){
            return;
        }
        if(!this.disabled){
            if(this.menu && !this.menu.isVisible() && !this.ignoreNextClick){
                this.showMenu();
            }
            this.fireEvent("click", this, e);
            if(this.handler){
                this.handler.call(this.scope || this, this, e);
            }
        }
    }
});
// Add xtype
Ext.ComponentMgr.registerType('linkbutton', Ext.LinkButton);