" Some parts adapted from https://github.com/vim-scripts/Smart-Tabs
" With inspiration from  https://www.emacswiki.org/emacs/SmartTabs

function! s:InIndent() abort
    return strpart(getline('.'), 0, col('.') - 1) =~# '^\s*$'
endfunction

function! s:SID() abort
    return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction

function! s:TabWidth() abort
    if &sts > 0
        return &sts
    endif

    if exists('b:lst_saved_sw')
        if b:lst_saved_sw != 0
            return b:lst_saved_sw
        else
            return b:lst_saved_ts
        endif
    else
        if &sw != 0
            return &sw
        else
            return &ts
        endif
    endif
endfun

function! s:SetWorkingTabs() abort
    setlocal ts=256
    setlocal sw=256
endfunction

function! s:RestoreUserTabs() abort
    execute 'setlocal ts=' . b:lst_saved_ts
    execute 'setlocal sw=' . b:lst_saved_sw
endfunction

function! s:SaveContext() abort
    let b:lst_saved_ts = &ts
    let b:lst_saved_sw = &sw
    let b:lst_saved_cino = &cino
    let b:lst_saved_view = winsaveview()
endfunction

function! s:RestoreContext() abort
    call s:RestoreUserTabs()
    execute 'setlocal cino=' . b:lst_saved_cino

    let cursor = getcurpos()
    let b:lst_saved_view['lnum']     = cursor[1]
    let b:lst_saved_view['col']      = cursor[2] - 1
    let b:lst_saved_view['coladd']   = cursor[3]
    let b:lst_saved_view['curswant'] = virtcol('.') - 1
    call winrestview(b:lst_saved_view)

    unlet b:lst_saved_ts
    unlet b:lst_saved_sw
    unlet b:lst_saved_cino
    unlet b:lst_saved_view
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

    call s:SetWorkingTabs()
endfunction

function! s:GetUserPos(pos) abort
    call s:RestoreUserTabs()

    let l = line(a:pos)
    " Work-around for virtcol() returning end of tab
    " rather than beginning. Beginning is one character
    " right of the end of the previous character
    let c = virtcol([l, col(a:pos) - 1]) + 1
    let p = [l, c]

    call s:SetWorkingTabs()

    return p
endfunction

function! s:SetUserCursor(pos) abort
    call s:RestoreUserTabs()

    execute 'normal! ' . a:pos[0] . 'G' . a:pos[1] . '|'

    call s:SetWorkingTabs()
endfunction

function! s:CallHookBefore() abort
    return "\<c-r>=" . s:SID() . "HookBefore()\<cr>"
endfunction

function! s:CallHookAfter() abort
    return "\<c-r>=" . s:SID() . "HookAfter()\<cr>"
endfunction

function! s:MapOperator(op) abort
    "execute 'inoremap <buffer> <silent> ' . a:op . ' :<c-u>let b:lst_op="' . a:op . '"<cr>:set operatorfunc=<SID>ApplyOperator<cr>g@'
    "execute 'cnoremap <buffer> <silent> ' . a:op . ' :<c-u>let b:lst_op="' . a:op . '"<cr>:set operatorfunc=<SID>ApplyOperator<cr>g@'
    execute 'vnoremap <buffer> <silent> ' . a:op . ' :<c-u>let b:lst_ct=v:count1<cr>:let b:lst_op="' . a:op . '"<cr>:call <SID>ApplyOperator(visualmode())<cr>'
endfunction

function! s:ShiftBlockRight() abort
    let p1 = s:GetUserPos("'<")
    let p2 = s:GetUserPos("'>")
    let c = min([p1[1], p2[1]])

    for l in range(p1[0], p2[0])
        call s:SetUserCursor([l, c])

        if s:InIndent()
            execute "normal! \<c-v>" . b:lst_ct . '>'
        else
            execute 'normal! i' . repeat(' ', s:TabWidth() * b:lst_ct) . "\<esc>"
        endif
    endfor

    call s:SetUserCursor([min([p1[0], p2[0]]), c])
endfunction

function! s:ShiftBlockLeft() abort
    let p1 = s:GetUserPos("'<")
    let p2 = s:GetUserPos("'>")
    let c = min([p1[1], p2[1]])

    for l in range(p1[0], p2[0])
        call s:SetUserCursor([l, c])

        if s:InIndent()
            execute "normal! \<c-v>" . b:lst_ct . '<'
        else
            " TODO
        endif
    endfor

    call s:SetUserCursor([min([p1[0], p2[0]]), c])
endfunction

function! <SID>HookBefore() abort
    call s:SaveContext()
    call s:ConfigureSmartly()

    return ''
endfunction

function! <SID>HookAfter() abort
    call s:RestoreContext()

    return ''
endfunction

function! <SID>ApplyOperator(type) abort
    call <SID>HookBefore()

    if a:type ==# 'v'
        execute 'normal! `<v`>' . b:lst_ct . b:lst_op
    elseif a:type ==# 'V'
        execute 'normal! `<V`>' . b:lst_ct . b:lst_op
    elseif a:type ==# ''
        if b:lst_op ==# '>'
            call s:ShiftBlockRight()
        elseif b:lst_op ==# '<'
            call s:ShiftBlockLeft()
        else
            execute "normal! `<\<c-v>`>" . b:lst_ct . b:lst_op
        endif
    elseif a:type ==# 'char'
        execute 'normal! `[v`]' . b:lst_op
    elseif a:type ==# 'line'
        execute 'normal! `[V`]' . b:lst_op
    endif

    call <SID>HookAfter()

    unlet b:lst_op
    unlet b:lst_ct
endfunction

function! <SID>InsertCR() abort
    return s:CallHookBefore() . "\<cr>" . s:CallHookAfter()
endfunction

function! <SID>InsertTab() abort
    if s:InIndent()
        return "\<tab>"
    endif

    let sts = s:TabWidth()
    let sp = (virtcol('.') % sts)

    if sp == 0
        let sp = sts
    endif

    return repeat(' ', 1 + sts - sp)
endfun

function! less_smart_tabs#enable() abort
    if &expandtab
        echo 'expandtab is enabled, skipped enabling less_smart_tabs'
        return
    endif

    inoremap <buffer> <silent> <expr> <tab> <SID>InsertTab()

    inoremap <buffer> <silent> <expr> <cr> <SID>InsertCR()

    call s:MapOperator('>')
    call s:MapOperator('<')
    call s:MapOperator('=')
endfunction

