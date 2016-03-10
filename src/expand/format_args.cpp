/*
 */
#include <synext.hpp>
#include "../parse/common.hpp"
#include "../parse/parseerror.hpp"
#include "../parse/tokentree.hpp"
#include "../parse/lex.hpp"

class CFormatArgsExpander:
    public ExpandProcMacro
{
    bool    expand_early() const override { return true; }
    
    ::std::unique_ptr<TokenStream> expand(Span sp, const ::std::string& ident, const TokenTree& tt, AST::Module& mod) override
    {
        Token   tok;
        
        auto lex = TTStream(tt);
        if( ident != "" )
            ERROR(sp, E0000, "format_args! doesn't take an ident");
        
        GET_CHECK_TOK(tok, lex, TOK_STRING);
        auto format_string = mv$(tok.str());
        
        // TODO: Interpolated expression "tokens"
        ::std::map< ::std::string, TokenTree>   named_args;
        ::std::vector<TokenTree>    free_args;
        
        while( GET_TOK(tok, lex) == TOK_COMMA )
        {
            if( lex.lookahead(0) == TOK_IDENT && lex.lookahead(1) == TOK_EQUAL )
            {
                GET_CHECK_TOK(tok, lex, TOK_IDENT);
                auto name = mv$(tok.str());
                GET_CHECK_TOK(tok, lex, TOK_EQUAL);
                auto expr_tt = Parse_TT_Expr(lex);
                
                named_args.insert( ::std::make_pair(mv$(name), mv$(expr_tt)) );
            }
            else
            {
                auto expr_tt = Parse_TT_Expr(lex);
                free_args.push_back( mv$(expr_tt) );
            }
        }
        
        // TODO: Expand format_args!
        return box$( TTStreamO(TokenTree(::std::vector<TokenTree>{TokenTree(TOK_PAREN_OPEN), TokenTree(TOK_PAREN_CLOSE)})) );
    }
};

STATIC_MACRO("format_args", CFormatArgsExpander);

