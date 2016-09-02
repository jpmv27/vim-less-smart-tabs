function! s:IsEnabled() abort
    return get(b:, 'lst_enable', get(g:, 'lst_enable', 0)) && (!&et)
endfunction

function! s:InIndent() abort
    return strpart(getline('.'), 0, col('.') - 1) =~ '^\s*$'
endfunction

function! s:TabWidth() abort
    return (&sts <= 0) ? ((&sw == 0) ? &ts : &sw) : &sts
endfun

function! <SID>InsertTab() abort
    if (!s:IsEnabled()) || s:InIndent()
        return "\<Tab>"
    endif

    let sts = s:TabWidth()
    let sp = (virtcol('.') % sts)

    if sp == 0
        let sp = sts
    endif

    return strpart("                  ", 0, 1 + sts - sp)
endfun

imap <silent> <expr> <tab> <SID>InsertTab()

