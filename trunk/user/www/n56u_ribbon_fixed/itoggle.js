/*
 * Classic (Padavan 老毛子) style toggles.
 *
 * The WebUI markup keeps three elements per option:
 *   #<id>_on_of  - container for the fancy iOS style switch (engage.itoggle)
 *   #<id>_fake   - checkbox that mirrors the current state
 *   #<id>_1/_0   - the real radio inputs that are submitted with the form
 *
 * This implementation drops the fancy switch and restores the original
 * "是 / 否" radio pair, which is both lighter and easier to read.
 * Pages without the radio pair fall back to a plain checkbox.
 */
function init_itoggle(id, func)
{
    var $j = window.jQuery;
    var obj_f = $j('#' + id + '_fake');
    var box   = $j('#' + id + '_on_of');
    var r_on  = $j('#' + id + '_1');
    var r_off = $j('#' + id + '_0');

    if (r_on.length && r_off.length) {
        var holder = r_on.closest('div');
        /* the radios are hidden off-screen by the pages: bring them back */
        holder.css({
            'position': 'static',
            'margin-left': '0',
            'display': 'inline-block'
        });
        box.hide();

        var sync = function () {
            if (r_on.prop('checked')) {
                obj_f.prop('checked', true).attr('value', 1);
            } else {
                obj_f.prop('checked', false).attr('value', 0);
            }
            if (typeof (func) === 'function')
                func();
        };

        r_on.off('change.classicToggle').on('change.classicToggle', sync);
        r_off.off('change.classicToggle').on('change.classicToggle', sync);
        sync();
        return;
    }

    if (!obj_f.length)
        return;

    /* fallback: plain checkbox */
    box.hide();
    obj_f.show().css({
        'margin': '0 6px 0 0',
        'vertical-align': 'middle'
    });
    obj_f.off('change.classicToggle').on('change.classicToggle', function () {
        this.value = this.checked ? 1 : 0;
        if (typeof (func) === 'function')
            func();
    });
}
