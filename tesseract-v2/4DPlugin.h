/* --------------------------------------------------------------------------------
 #
 #	4DPlugin.h
 #	source generated by 4D Plugin Wizard
 #	Project : Tesseract
 #	author : miyako
 #	2019/02/25
 #
 # --------------------------------------------------------------------------------*/

#define NOMINMAX

#include "4DPluginAPI.h"

/* tesseract */
#include "baseapi.h"
#include "dict.h"
#include "osdetect.h"
#include "renderer.h"
#include "simddetect.h"
#include "strngs.h"

/* jsoncpp */
#include "json.h"

#include "tiffio.h"

/* leptonica */
#include "alltypes.h"

//#include "allheaders.h"

#define LIBLEPT_MAJOR_VERSION   1
#define LIBLEPT_MINOR_VERSION   80
#define LIBLEPT_PATCH_VERSION   0

#ifdef __cplusplus
extern "C" {
#endif  /* __cplusplus */
    
    LEPT_DLL extern char * getLeptonicaVersion ();
    LEPT_DLL extern void lept_free ( void *ptr );
    LEPT_DLL extern char * getImagelibVersions ();
    
    LEPT_DLL extern PIXA * pixaReadMemMultipageTiff ( const l_uint8 *data, size_t size );
    LEPT_DLL extern PIXA * pixaReadMultipageTiff ( const char *filename );
    
    LEPT_DLL extern PIX * pixReadMemTiff ( const l_uint8 *cdata, size_t size, l_int32 n );
    LEPT_DLL extern PIX * pixReadStreamTiff ( FILE *fp, l_int32 n );
    
    LEPT_DLL extern PIX * pixReadMemWebP ( const l_uint8 *filedata, size_t filesize );
    LEPT_DLL extern PIX * pixReadStreamWebP ( FILE *fp );
    
    LEPT_DLL extern PIX * pixReadMemBmp ( const l_uint8 *cdata, size_t size );
    LEPT_DLL extern PIX * pixReadStreamBmp ( FILE *fp );
    
    LEPT_DLL extern PIX * pixReadMemGif ( const l_uint8 *cdata, size_t size );
    LEPT_DLL extern PIX * pixReadStreamGif ( FILE *fp );
    
    LEPT_DLL extern PIX * pixReadMemPng ( const l_uint8 *filedata, size_t filesize );
    LEPT_DLL extern PIX * pixReadStreamPng ( FILE *fp );
    
    LEPT_DLL extern PIX * pixReadMemPnm ( const l_uint8 *data, size_t size );
    LEPT_DLL extern PIX * pixReadStreamPnm ( FILE *fp );
    
    LEPT_DLL extern PIX * pixReadMemJpeg ( const l_uint8 *data, size_t size, l_int32 cmflag, l_int32 reduction, l_int32 *pnwarn, l_int32 hint );
    LEPT_DLL extern PIX * pixReadStreamJpeg ( FILE *fp, l_int32 cmapflag, l_int32 reduction, l_int32 *pnwarn, l_int32 hint );
    
    LEPT_DLL extern PIX * pixReadMem ( const l_uint8 *data, size_t size );
    LEPT_DLL extern PIX * pixRead ( const char *filename );
    
    LEPT_DLL extern void pixDestroy ( PIX **ppix );
    
    LEPT_DLL extern BOX * boxaGetBox ( BOXA *boxa, l_int32 index, l_int32 accessflag );
    
#ifdef __cplusplus
}
#endif  /* __cplusplus */

// --- Tesseract
void Tesseract_Get_info(sLONG_PTR *pResult, PackagePtr pParams);
void Tesseract(sLONG_PTR *pResult, PackagePtr pParams);
