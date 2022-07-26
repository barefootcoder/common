/* PRE 4.x:                                 */
/*    https://forum.vivaldi.net/topic/15834 */
/*    ... later ...                         */
/*    https://forum.vivaldi.net/topic/42105 */
/* 4.x AND BEYOND:                          */
/*    https://forum.vivaldi.net/topic/62447 */
/*    ... later ...                         */
/*    https://forum.vivaldi.net/topic/56809 */


/* ======================================== */
/* FOR THIS CODE TO WORK, YOU *MUST* SET    */
/* TAB POSITION TO _TOP_.                   */
/* ======================================== */


/* ======================================== */
/* MAIN CODE                                */
/* courtesy @nomadic (7/13/22)              */
/* from thread #4                           */
/* ======================================== */

#browser {
  --addressBarPaddingRight: 137px;
  --headerElementsHeight: 34px;
  --tabBarPaddingRightToSeeTrashAndSync: 92px;
  /* uncomment the line below to unify tab bar color with the address bar's */
  --unified: transparent;
  --backgroundColor: var(--unified, var(--colorBg));
  --backgroundColorAccent: var(--unified, var(--colorAccentBg));
}

/* top addressbar above top tabbar */
#header {
  padding-top: 36px;
}

/* allows mainbar to be positioned absolute */
#main {
  overflow: unset;
  position: unset;
}

.mainbar {
  position: absolute;
  top: 0;
  padding-left: 34px;
  padding-right: var(--addressBarPaddingRight);
  width: 100%;
  z-index: 2 !important;
}

/* not sure if needed... */
/* brings vivaldi button and win controls to front */
#browser.tabs-top #header {
  backdrop-filter: unset;
  contain: unset;
}
#browser.tabs-top.address-top #main {
  overflow: visible;
}

/* Sets tabs to fill entire bar */
#tabs-tabbar-container.top {
  margin-left: 0px !important;
  margin-right: -90px !important;
}
#browser.tabs-top.address-top #tabs-tabbar-container > div {
  padding-left: 2px;
}

/* bookmark bar enabled */
#browser.tabs-top.address-top.bookmark-bar-top #header {
  padding-top: 65px;
}
#browser.tabs-top.address-top.bookmark-bar-top .bookmark-bar {
  position: fixed;
  top: 34px;
  left: 0;
  right: 0;
}
#browser.tabs-top.address-top.bookmark-bar-top.maximized:not(.tabs-at-edge) .bookmark-bar {
  top: 41px;
}

/* horizontal menu enabled */
#browser.tabs-top.address-top.horizontal-menu #header {
  --headerElementsHeight: 24px;
}
/* Make window controls same color as menu bar */
#browser.tabs-top.address-top.horizontal-menu .window-buttongroup {
  background-color: var(--colorTabBar);
}
#browser.tabs-top.address-top.horizontal-menu #header {
  padding-top: 38px !important;
}
#browser.tabs-top.address-top.horizontal-menu .topmenu {
  transform: translateY(-38px);
  margin-bottom: 0;
  color: var(--colorFg);
}
#browser.tabs-top.address-top.horizontal-menu #tabs-tabbar-container {
  padding-top: 0;
}
#browser.tabs-top.address-top.horizontal-menu .mainbar {
  padding: unset;
  transform: translateY(24px);
}

/* bookmark bar & horizontal menu enabled */
#browser.tabs-top.address-top.horizontal-menu.bookmark-bar-top #header {
  padding-top: 65px !important;
}
#browser.tabs-top.address-top.horizontal-menu.bookmark-bar-top .topmenu {
  transform: translateY(-65px);
}
#browser.tabs-top.address-top.horizontal-menu.bookmark-bar-top .bookmark-bar {
  top: 58px !important;
}

/* ---------------------------- */
/*           New Stuff          */
/* ---------------------------- */

/* Shrink height of all the window action buttons */
.window-buttongroup button.window-minimize,
.window-buttongroup button.window-maximize,
.window-buttongroup button.window-close {
  height: var(--headerElementsHeight) !important;
}
/* Shrink height of Vivaldi menu button */
#titlebar button.vivaldi {
  height: var(--headerElementsHeight) !important;
  padding-top: 0;
}

/* Remove empty space to the right of tabs and above tabs*/
#tabs-container {
  padding-right: var(--tabBarPaddingRightToSeeTrashAndSync) !important;
}
#tabs-tabbar-container.top {
  padding-top: unset !important;
}

/* Make other title bar elements have the same color as the address bar elements */
#titlebar button.vivaldi,
.window-buttongroup {
  background-color: var(--backgroundColor);
}
.color-behind-tabs-off #titlebar button.vivaldi,
.color-behind-tabs-off .window-buttongroup {
  background-color: var(--backgroundColorAccent);
}
.toolbar-mainbar .toolbar-extensions,
.toolbar-mainbar {
  background-color: var(--backgroundColor);
}
.color-behind-tabs-off .toolbar-mainbar .toolbar-extensions,
.color-behind-tabs-off .toolbar-mainbar {
  background-color: var(--backgroundColorAccent);
}

/* Fix tabs showing above address bar and search dropdowns */
#tabs-tabbar-container.top {
  z-index: 0;
}

/* Remove line under address bar and extensions bar */
.address-top .mainbar > .toolbar-mainbar .toolbar-extensions:after,
.address-top .mainbar > .toolbar-mainbar:after {
  content: unset;
}

/* Move extension popups down to avoid crossing drag region which leads to dead zone */
.extension-popup.top {
  margin-top: 29px;
}
#browser.tabs-top.address-top.horizontal-menu .extension-popup.top {
  margin-top: 7px;
}
#browser.tabs-top.address-top.bookmark-bar-top .extension-popup.top {
  margin-top: 58px;
}
#browser.tabs-top.address-top.bookmark-bar-top.horizontal-menu .extension-popup.top {
  margin-top: 2px;
}


/* ======================================== */
/* FURTHER COSMETIC TWEAKS                  */
/* courtesy @dude99 (6/12/21)               */
/* from thread #3                           */
/* ======================================== */

/* Unify TabBar and AddressBar Color Palette */
/* ENABLE ONLY ONE SET OF THESE! Disable the other set by adding "/" at beginning of line. */
/*    ON: enable these lines: */
.color-behind-tabs-off#browser.tabs-top.address-top .UrlBar > div:not(.UrlBar-AddressField):not(.UrlBar-SearchField) {color: var(--colorImageFg, var(--colorFg));}
.color-behind-tabs-on#browser.tabs-top.address-top .UrlBar > div:not(.UrlBar-AddressField):not(.UrlBar-SearchField) {color: var(--colorImageFg, var(--colorAccentFg));}
/*    OFF: enable these lines: */
/ #browser.tabs-top.address-top #titlebar {background-color: var(--colorBg); color: var(--colorFg);}
/ #browser.tabs-top.address-top .color-behind-tabs-off #titlebar {background-color: var(--colorAccentBg); color: var(--colorAccentFg);}
/* end Unify Palette */


/* ======================================== */
/* INITIAL COSMETIC TWEAKS                  */
/* courtesy @nomadic (9/20/20)              */
/* from thread #2                           */
/* ======================================== */

/* corner rounding */
.tabs-top .tab-position .tab {
    border-top-left-radius: var(--radiusHalf);
    border-top-right-radius: var(--radiusHalf);
    border-bottom-left-radius: unset;
    border-bottom-right-radius: unset;
}

/* Fix Fillets */
.tabs-top .tab.active:not(.marked):not(.tab-mini):before {
    top: unset;
    bottom: 0;
    -webkit-mask-image: radial-gradient(circle at 0 0, rgba(0, 0, 0, 0) 70%, #000 73%);
}
.tabs-top .tab.active:not(.marked):not(.tab-mini):after {
    top: unset;
    bottom: 0;
    transform: unset;
    -webkit-mask-image: radial-gradient(circle at 100% 0, rgba(0, 0, 0, 0) 70%, #000 73%);
}

/* tab group indicators*/
.tabs-top .tab-strip .tab-group-indicator {
    bottom: 28px !important;
}
/* Remove line between address bar and bookmark bar */
.address-top .toolbar-mainbar:after {
    content: unset;
}

/* Remove line between bookmark bar and tabs */
.bookmark-bar {
    border-bottom-width: 0px !important;
}

.bookmark-bar {
    background-color: var(--colorAccentBg);
}
.color-behind-tabs-off .bookmark-bar button {
    background-color: var(--colorAccentBg);
}

.color-behind-tabs-on .bookmark-bar {
    background-color: var(--colorBg);
}
.color-behind-tabs-on .bookmark-bar button {
    background-color: var(--colorBg);
}
