" Some parts adapted from https://github.com/vim-scripts/Smart-Tabs
" With inspiration from  https://www.emacswiki.org/emacs/SmartTabs

function! s:InIndent() abort
    return strpart(getline('.'), 0, col('.') - 1) =~# '^\s*$'
endfunction

function! s:SID() abort
    return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction

function! s:TabWidth() abort
    return (&sts <= 0) ? ((&sw == 0) ? &ts : &sw) : &sts
endfun

function! s:SaveContext() abort
    let b:lst_saved_ts = &ts
    let b:lst_saved_sw = &sw
    let b:lst_saved_cino = &cino
    let b:lst_saved_view = winsaveview()
endfunction

function! s:RestoreContext() abort
    execute 'setlocal ts=' . b:lst_saved_ts
    execute 'setlocal sw=' . b:lst_saved_sw
    execute 'setlocal cino=' . b:lst_saved_cino
    call winrestview(b:lst_saved_view)

    unlet b:lst_saved_ts
    unlet b:lst_saved_sw
    unlet b:lst_saved_cino
    unlet b:lst_saved_view
endfunction

function! s:UpdateSavedCursorPos() abort
    let cursor = getcurpos()

    let b:lst_saved_view['lnum']     = cursor[1]
    let b:lst_saved_view['col']      = cursor[2] - 1
    let b:lst_saved_view['coladd']   = cursor[3]
    let b:lst_saved_view['curswant'] = cursor[4]
endfunction

function! s:ConfigureSmartly() abort
    if &cin
        " Some cinoptions default to the value of shiftwidth
        " Since we are changing shiftwidth, we need to pin those
        " values to the current shiftwidth before changing it
        if &cino !~# '(\d\+'
            execute 'setlocal cino+=(' . &sw * 2
        endif
        if &cino !~# 'u\d\+'
            execute 'setlocal cino+=u' . &sw
        endif
    endif

    setlocal ts=256
    setlocal sw=256
endfunction

function! s:CallHookBefore() abort
    return "\<c-r>=" . s:SID() . "HookBefore()\<CR>"
endfunction

function! s:CallHookAfter() abort
    return "\<c-r>=" . s:SID() . "HookAfter()\<CR>"
endfunction

function! <SID>InsertTab() abort
    if s:InIndent()
        return "\<Tab>"
    endif

    let sts = s:TabWidth()
    let sp = (virtcol('.') % sts)

    if sp == 0
        let sp = sts
    endif

    return repeat(' ', 1 + sts - sp)
endfun

function! <SID>HookBefore() abort
    call s:SaveContext()
    call s:ConfigureSmartly()

    return ''
endfunction

function! <SID>HookAfter() abort
    call s:UpdateSavedCursorPos()
    call s:RestoreContext()

    return ''
endfunction

function! <SID>InsertCR() abort
    return s:CallHookBefore() . "\<CR>" . s:CallHookAfter()
endfunction

function! less_smart_tabs#enable() abort
    if &expandtab
        echo 'expandtab is enabled, skipped enabling less_smart_tabs'
        return
    endif

    imap <buffer> <silent> <expr> <tab> <SID>InsertTab()
    inoremap <buffer> <silent> <expr> <CR> <SID>InsertCR()
endfunction

