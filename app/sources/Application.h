//
// Created by AlexBychek on 24.06.2025.
//

#ifndef APPLICATION_H
#define APPLICATION_H

#include "wx/wx.h"

class MyApp : public wxApp
{
public:
    virtual bool OnInit() wxOVERRIDE;
};

class MyFrame : public wxFrame
{
public:
    MyFrame(const wxString& title);

    void OnQuit(wxCommandEvent& event);
    void OnAbout(wxCommandEvent& event);

private:
    wxDECLARE_EVENT_TABLE();
};

#endif //APPLICATION_H
