/////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/carbon/dcscreen.cpp
// Purpose:     wxScreenDC class
// Author:      Stefan Csomor
// Modified by:
// Created:     1998-01-01
// Copyright:   (c) Stefan Csomor
// Licence:     wxWindows licence
/////////////////////////////////////////////////////////////////////////////

#include "wx/wxprec.h"

#include "wx/dcscreen.h"
#include "wx/osx/dcscreen.h"

#include "wx/osx/private.h"
#include "wx/osx/private/available.h"
#include "wx/graphics.h"

wxIMPLEMENT_ABSTRACT_CLASS(wxScreenDCImpl, wxWindowDCImpl);

// TODO : for the Screenshot use case, which doesn't work in Quartz
// we should do a GetAsBitmap using something like
// http://www.cocoabuilder.com/archive/message/cocoa/2005/8/13/144256

// Create a DC representing the whole screen
wxScreenDCImpl::wxScreenDCImpl( wxDC *owner ) :
   wxWindowDCImpl( owner )
{
#if !wxOSX_USE_IPHONE
    CGRect cgbounds ;
    cgbounds = CGDisplayBounds(CGMainDisplayID());
    m_width = (wxCoord)cgbounds.size.width;
    m_height = (wxCoord)cgbounds.size.height;
    SetGraphicsContext( wxGraphicsContext::Create() );
    m_ok = true ;
#endif
    m_contentScaleFactor = wxOSXGetMainScreenContentScaleFactor();
}

wxScreenDCImpl::~wxScreenDCImpl()
{
    wxDELETE(m_graphicContext);
}

#if wxOSX_USE_IPHONE
// Apple has allowed usage of this API as of 15th Dec 2009w
extern CGImageRef UIGetScreenImage();
#endif

// TODO Switch to CGWindowListCreateImage for 10.5 and above

wxBitmap wxScreenDCImpl::DoGetAsBitmap(const wxRect *subrect, const int& displayIndex) const
{
    int x = 0;
    int y = 0;
    int width = m_width;
    int height = m_height;

    if ( subrect )
    {
        x = subrect->GetX();
        y = subrect->GetY();
        width = subrect->GetWidth();
        height = subrect->GetHeight();
    }

#if !wxOSX_USE_IPHONE
    CGRect srcRect = CGRectMake(x, y, width, height);

    //////
    const int maxDisplay = 128;
    CGDirectDisplayID displays[maxDisplay];
    CGDisplayCount displayCount;
    const CGDisplayErr err = CGGetDisplaysWithRect(srcRect, maxDisplay
                                                   , displays, &displayCount);
    if (err || displayCount == 0)
    {
        return wxNullBitmap;
    }

    if ( subrect )
    {
        srcRect = CGRectOffset( srcRect, -x, -y ) ;
    }

    wxCFRef<CGDisplayModeRef> mode = CGDisplayCopyDisplayMode(displays[ displayCount > 1 ? displayCount - 1 : 0 ]);
    size_t w = CGDisplayModeGetWidth(mode);
    size_t pixelsw = CGDisplayModeGetPixelWidth(mode);
    double scaleFactor = (double)pixelsw/w;

    wxBitmap bmp(wxSize(width * scaleFactor
                 , height * scaleFactor)
                 , 32, scaleFactor, true);

    CGImageRef image = NULL;

//    CGDirectDisplayID displayID = CGMainDisplayID();
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 140000
    if ( WX_IS_MACOS_AVAILABLE(14,4) )
    {
        image = wxOSXCreateCGImageFromDisplay(displayIndex);
    }
    else
#endif
    {
#if __MAC_OS_X_VERSION_MAX_ALLOWED < 150000
    image = CGDisplayCreateImage(displays[ displayCount > 1 ? displayCount - 1 : 0 ]);
//    image = CGDisplayCreateImage(kCGNullDirectDisplay);
#endif
    }

    if ( image != nullptr )
    {
        CGContextRef context = (CGContextRef)bmp.GetHBITMAP();

        CGContextSaveGState(context);

        CGContextTranslateCTM( context, 0,  height);
        CGContextScaleCTM( context, 1, -1 );

        CGContextDrawImage(context,srcRect, image);
        CGContextRestoreGState(context);

        CGImageRelease(image);
    }

#else
    // TODO implement using UIGetScreenImage, CGImageCreateWithImageInRect, CGContextDrawImage
#endif
    return bmp;
}
